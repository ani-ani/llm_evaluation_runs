module max_pair_product(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] pairs [0:7][0:1],
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE     = 4'd0;
    localparam [3:0] MULT     = 4'd1;
    localparam [3:0] ABS      = 4'd2;
    localparam [3:0] COMPARE  = 4'd3;
    localparam [3:0] DONE     = 4'd4;

    // Internal registers
    reg [3:0] state;
    reg [2:0] pair_idx;          // 0-7 for 8 pairs
    reg signed [15:0] product;   // Signed 16-bit product
    reg signed [15:0] abs_product; // Absolute value
    reg [15:0] current_max;      // Running maximum
    reg [15:0] next_max;         // Next max value
    reg computation_done;        // Flag for all pairs processed
    reg [1:0] cycle_count;       // Cycles per pair (mult, abs, compare)

    // Reset and state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            pair_idx <= 3'd0;
            product <= 16'sd0;
            abs_product <= 16'sd0;
            current_max <= 16'd0;
            next_max <= 16'd0;
            computation_done <= 1'b0;
            cycle_count <= 2'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    computation_done <= 1'b0;
                    pair_idx <= 3'd0;
                    current_max <= 16'd0;
                    cycle_count <= 2'd0;
                    if (start) begin
                        state <= MULT;
                    end
                end

                MULT: begin
                    // Compute signed product
                    product <= pairs[pair_idx][0] * pairs[pair_idx][1];
                    cycle_count <= cycle_count + 2'd1;
                    if (cycle_count == 2'd0) begin
                        // First cycle of MULT
                        state <= MULT;
                    end else begin
                        // Move to ABS after 1 cycle
                        state <= ABS;
                        cycle_count <= 2'd0;
                    end
                end

                ABS: begin
                    // Compute absolute value
                    if (product[15]) begin
                        // Negative: 2's complement
                        abs_product <= ~product + 16'sd1;
                    end else begin
                        // Positive: already absolute
                        abs_product <= product;
                    end
                    cycle_count <= cycle_count + 2'd1;
                    if (cycle_count == 2'd0) begin
                        state <= ABS;
                    end else begin
                        state <= COMPARE;
                        cycle_count <= 2'd0;
                    end
                end

                COMPARE: begin
                    // Compare with current max
                    if (abs_product > current_max) begin
                        current_max <= abs_product;
                    end
                    cycle_count <= cycle_count + 2'd1;
                    if (cycle_count == 2'd0) begin
                        state <= COMPARE;
                    end else begin
                        cycle_count <= 2'd0;
                        // Check if all pairs processed
                        if (pair_idx == 3'd7) begin
                            state <= DONE;
                        end else begin
                            pair_idx <= pair_idx + 3'd1;
                            state <= MULT;
                        end
                    end
                end

                DONE: begin
                    // Set result and done pulse
                    result <= current_max;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    result <= 16'd0;
                    done <= 1'b0;
                    pair_idx <= 3'd0;
                    product <= 16'sd0;
                    abs_product <= 16'sd0;
                    current_max <= 16'd0;
                    next_max <= 16'd0;
                    computation_done <= 1'b0;
                    cycle_count <= 2'd0;
                end
            endcase
        end
    end

endmodule