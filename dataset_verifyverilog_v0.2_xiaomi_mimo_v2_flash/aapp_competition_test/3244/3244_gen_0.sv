module ring_reconstruct (
    input clk,
    input rst_n,
    input start,
    input [2:0] valid_count,
    input [31:0] b0, b1, b2, b3, b4, b5, b6, b7,
    output reg [31:0] a0, a1, a2, a3, a4, a5, a6, a7,
    output reg done,
    output reg error
);

    // Parameters
    parameter N = 8;
    parameter WIDTH = 32;
    parameter IDLE = 3'b000;
    parameter INIT = 3'b001;
    parameter CHECK = 3'b010;
    parameter ADJUST = 3'b011;
    parameter OUTPUT = 3'b100;
    parameter ERROR_STATE = 3'b101;

    // State register
    reg [2:0] state;
    reg [2:0] next_state;

    // Internal registers
    reg [WIDTH-1:0] b [0:N-1];
    reg [WIDTH-1:0] a [0:N-1];
    reg [WIDTH-1:0] a_temp [0:N-1];
    reg [WIDTH-1:0] diff;
    reg [WIDTH-1:0] k;
    reg [WIDTH-1:0] adjust_val;
    reg [2:0] counter;
    reg [2:0] phase_counter;
    reg signed [WIDTH:0] signed_diff;
    reg signed [WIDTH:0] signed_k;
    reg signed [WIDTH:0] signed_temp;
    reg [2:0] i_reg;

    // Combinational logic for state transition
    always @(*) begin
        case (state)
            IDLE: next_state = start ? INIT : IDLE;
            INIT: next_state = (counter == 3'd5) ? CHECK : INIT;
            CHECK: next_state = (counter == 3'd3) ? ADJUST : CHECK;
            ADJUST: next_state = (counter == 3'd5) ? OUTPUT : ADJUST;
            OUTPUT: next_state = IDLE;
            ERROR_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            error <= 1'b0;
            counter <= 3'd0;
            phase_counter <= 3'd0;
            i_reg <= 3'd0;
            diff <= 0;
            k <= 0;
            adjust_val <= 0;
            signed_diff <= 0;
            signed_k <= 0;
            signed_temp <= 0;
            // Reset outputs
            a0 <= 0; a1 <= 0; a2 <= 0; a3 <= 0;
            a4 <= 0; a5 <= 0; a6 <= 0; a7 <= 0;
            // Reset temp arrays
            a_temp[0] <= 0; a_temp[1] <= 0; a_temp[2] <= 0; a_temp[3] <= 0;
            a_temp[4] <= 0; a_temp[5] <= 0; a_temp[6] <= 0; a_temp[7] <= 0;
            // Reset b array
            b[0] <= 0; b[1] <= 0; b[2] <= 0; b[3] <= 0;
            b[4] <= 0; b[5] <= 0; b[6] <= 0; b[7] <= 0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    counter <= 3'd0;
                    phase_counter <= 3'd0;
                    i_reg <= 3'd0;
                    if (start) begin
                        // Load input values into internal array
                        b[0] <= b0;
                        b[1] <= b1;
                        b[2] <= b2;
                        b[3] <= b3;
                        b[4] <= b4;
                        b[5] <= b5;
                        b[6] <= b6;
                        b[7] <= b7;
                        a_temp[0] <= 0; // Initialize a0_temp = 0
                    end
                end

                INIT: begin
                    counter <= counter + 1'b1;
                    case (counter)
                        3'd0: begin // Compute a1
                            a_temp[1] <= b[0] - a_temp[0]; // b[0] - a0 - a_{N-1}, but a_{N-1}=0 initially
                        end
                        3'd1: begin // Compute a2
                            a_temp[2] <= b[1] - a_temp[1] - a_temp[0];
                        end
                        3'd2: begin // Compute a3
                            a_temp[3] <= b[2] - a_temp[2] - a_temp[1];
                        end
                        3'd3: begin // Compute a4
                            a_temp[4] <= b[3] - a_temp[3] - a_temp[2];
                        end
                        3'd4: begin // Compute a5
                            a_temp[5] <= b[4] - a_temp[4] - a_temp[3];
                        end
                        3'd5: begin // Compute a6, prepare for check
                            a_temp[6] <= b[5] - a_temp[5] - a_temp[4];
                            // Also compute a7 for check phase preparation
                            // Note: this happens in next state or here? 
                            // Let's compute a7 here to finish forward pass
                            a_temp[7] <= b[6] - a_temp[6] - a_temp[5]; // Wait, a_temp[6] is computed in this cycle
                            // The formula needs a_temp[6], which we are computing now. 
                            // We need to wait one cycle or use combinational logic.
                            // Let's adjust logic: use sequential updates carefully.
                            // The assignment for a_temp[7] here depends on a_temp[6] which is updated same cycle.
                            // To fix: move a_temp[7] computation to a separate cycle or state.
                            // However, the spec says 15 cycles total.
                            // Let's use the next cycle (first cycle of CHECK) to compute final a7.
                        end
                    endcase
                end

                CHECK: begin
                    counter <= counter + 1'b1;
                    case (counter)
                        3'd0: begin
                            // Finish forward pass: compute a7
                            a_temp[7] <= b[6] - a_temp[6] - a_temp[5];
                        end
                        3'd1: begin
                            // Check constraint: a[7] + a[0] + a[1] should equal b[7]
                            // diff = (a[7] + a[0] + a[1] - b[7])
                            signed_diff <= (a_temp[7] + a_temp[0] + a_temp[1]) - b[7];
                        end
                        3'd2: begin
                            // Check if diff is zero or needs adjustment
                            // For even N=8, if diff != 0, we need adjustment
                            if (signed_diff != 0) begin
                                // Compute k = diff / 4
                                // Check if divisible
                                if (signed_diff[1:0] != 2'b00) begin
                                    // Not divisible by 4, no integer solution or error
                                    // Spec says error if no solution found
                                    error <= 1'b1;
                                end else begin
                                    signed_k <= signed_diff >>> 2; // Divide by 4
                                end
                            end
                        end
                    endcase
                end

                ADJUST: begin
                    counter <= counter + 1'b1;
                    // Apply adjustment: add k to even indices, subtract k from odd indices
                    // Check non-negativity
                    case (counter)
                        3'd0: begin // Even indices: 0, 2, 4, 6
                            if (signed_diff != 0) begin
                                signed_temp <= a_temp[0] + signed_k;
                            end else signed_temp <= a_temp[0];
                        end
                        3'd1: begin
                            if (signed_diff != 0) begin
                                if (signed_temp[WIDTH]) error <= 1'b1; // Check negative sign bit
                                else a_temp[0] <= signed_temp[WIDTH-1:0];
                            end
                            signed_temp <= a_temp[2] + signed_k;
                        end
                        3'd2: begin
                            if (signed_diff != 0) begin
                                if (signed_temp[WIDTH]) error <= 1'b1;
                                else a_temp[2] <= signed_temp[WIDTH-1:0];
                            end
                            signed_temp <= a_temp[4] + signed_k;
                        end
                        3'd3: begin
                            if (signed_diff != 0) begin
                                if (signed_temp[WIDTH]) error <= 1'b1;
                                else a_temp[4] <= signed_temp[WIDTH-1:0];
                            end
                            signed_temp <= a_temp[6] + signed_k;
                        end
                        3'd4: begin
                            if (signed_diff != 0) begin
                                if (signed_temp[WIDTH]) error <= 1'b1;
                                else a_temp[6] <= signed_temp[WIDTH-1:0];
                            end
                            // Odd indices: 1, 3, 5, 7
                            signed_temp <= a_temp[1] - signed_k;
                        end
                        3'd5: begin
                            if (signed_diff != 0) begin
                                if (signed_temp[WIDTH]) error <= 1'b1;
                                else a_temp[1] <= signed_temp[WIDTH-1:0];
                            end
                            // In the last cycle of ADJUST, we finish calculations.
                            // But we need to handle remaining odd indices.
                            // Since we have limited cycles, let's process 3, 5, 7.
                            // Wait, the spec says 15 cycles total.
                            // State transitions: IDLE(1) -> INIT(6) -> CHECK(3) -> ADJUST(5) -> OUTPUT(1).
                            // ADJUST has 5 cycles. We used 6 cycles in ADJUST here? No, counter goes 0 to 4 for 5 cycles?
                            // Let's consolidate ADJUST to 5 cycles.
                            // Cycle 4 (count=3): checked 6, now check 7?
                            // Let's do pattern: 0,2,4,6 in first 4 cycles, then 1,3,5,7 in last cycle or adjust state.
                            // To fit timing: 
                            // ADJUST cycle 0: eval 0
                            // ADJUST cycle 1: save 0, eval 2
                            // ADJUST cycle 2: save 2, eval 4
                            // ADJUST cycle 3: save 4, eval 6
                            // ADJUST cycle 4: save 6, eval 1,3,5,7 (needs more than 1 cycle).
                            // Timing is tight. 
                            // Optimization: Do all math in combinational logic, latch only in OUTPUT or adjust state.
                            // Let's restructure ADJUST to be 4 cycles, and 5th cycle to compute odd diffs.
                            // Wait, 15 cycles total is generous. 
                            // Let's stick to the explicit state machine. 
                            // Recalc ADJUST timing: 
                            // 0: compute all temp even sums (comb)
                            // 1: check even signs
                            // 2: compute all temp odd diffs
                            // 3: check odd signs
                            // 4: commit.
                            // This approach is safer.
                        end
                    endcase
                    // Override for simplified robust logic inside ADJUST block to fit 5 cycles:
                    if (counter == 3'd0) begin
                        // Check total range of adjustment
                        // Even indices
                        if (signed_diff != 0) begin
                             if ($signed(a_temp[0]) + signed_k < 0 || $signed(a_temp[2]) + signed_k < 0 ||
                                 $signed(a_temp[4]) + signed_k < 0 || $signed(a_temp[6]) + signed_k < 0) error <= 1'b1;
                             // Odd indices
                             if ($signed(a_temp[1]) - signed_k < 0 || $signed(a_temp[3]) - signed_k < 0 ||
                                 $signed(a_temp[5]) - signed_k < 0 || $signed(a_temp[7]) - signed_k < 0) error <= 1'b1;
                        end
                    end
                    if (counter == 3'd1 && !error && signed_diff != 0) begin
                        // Apply adjustments
                        a_temp[0] <= a_temp[0] + signed_k;
                        a_temp[2] <= a_temp[2] + signed_k;
                        a_temp[4] <= a_temp[4] + signed_k;
                        a_temp[6] <= a_temp[6] + signed_k;
                        a_temp[1] <= a_temp[1] - signed_k;
                        a_temp[3] <= a_temp[3] - signed_k;
                        a_temp[5] <= a_temp[5] - signed_k;
                        a_temp[7] <= a_temp[7] - signed_k;
                    end
                    // If diff is 0, do nothing. If error, state handles it.
                end

                OUTPUT: begin
                    done <= 1'b1;
                    // Only output if valid count matches or error
                    if (!error) begin
                        // Mask based on valid_count (3-8)
                        // The prompt implies we reconstruct for N=8, but valid_count adjusts valid inputs.
                        // We output computed values. If valid_count < 8, upper indices are don't care or 0?
                        // Let's output computed values and signal done.
                        // Spec: "Only 3 valid numbers used (adjustable via parameter)" 
                        // Wait, the description says "For the simplified implementation: N=8".
                        // And "Only 3 valid numbers used". This likely means valid_count <= 8.
                        // But the logic computes for N=8. We output all.
                        {a7, a6, a5, a4, a3, a2, a1, a0} <= {a_temp[7], a_temp[6], a_temp[5], a_temp[4], a_temp[3], a_temp[2], a_temp[1], a_temp[0]};
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
