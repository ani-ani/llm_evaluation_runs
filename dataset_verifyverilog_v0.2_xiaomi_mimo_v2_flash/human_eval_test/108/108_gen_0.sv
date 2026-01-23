module count_nums(
    input clk,
    input rst_n,
    input start,
    input [4:0] array_size,
    input signed [7:0] arr [0:15],
    output reg [4:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam ABS_SIGN = 3'b010;
    localparam DIGIT_LOOP = 3'b011;
    localparam CHECK = 3'b100;
    localparam NEXT = 3'b101;
    localparam FINISH = 3'b110;

    reg [2:0] state;
    reg [4:0] idx;
    reg signed [7:0] current_val;
    reg [7:0] abs_val;
    reg [7:0] orig_abs; // Store original absolute value for MSD calculation
    reg sign_flag;
    reg [4:0] digit_sum; // Sum of digits (max 27, fits in 5 bits)
    reg [2:0] digit_count; // Loop counter, max 3

    // State Transition and Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            idx <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    result <= 0;
                    idx <= 0;
                    if (start) state <= LOAD;
                end

                LOAD: begin
                    if (idx >= array_size) begin
                        state <= FINISH;
                    end else begin
                        current_val <= arr[idx];
                        state <= ABS_SIGN;
                    end
                end

                ABS_SIGN: begin
                    if (current_val < 0) begin
                        abs_val <= -current_val; // 2's complement negation
                        orig_abs <= -current_val;
                        sign_flag <= 1;
                    end else begin
                        abs_val <= current_val;
                        orig_abs <= current_val;
                        sign_flag <= 0;
                    end
                    digit_sum <= 0;
                    digit_count <= 0;
                    // If current_val is 0, we can skip the loop, but the loop handles it naturally (adds 0, abs becomes 0 immediately)
                    // However, if 0, next state should be CHECK (no loop needed essentially).
                    // But the loop logic `if abs_val == 0` check in next state will handle it.
                    state <= DIGIT_LOOP;
                end

                DIGIT_LOOP: begin
                    // Extract one digit and accumulate
                    if (abs_val > 0) begin
                        digit_sum <= digit_sum + (abs_val % 10);
                        abs_val <= abs_val / 10;
                    end
                    digit_count <= digit_count + 1;
                    
                    // Check termination condition for next state
                    if (abs_val == 0 || digit_count == 2) begin // 0,1,2 (3 iterations max for 8-bit number)
                        state <= CHECK;
                    end else begin
                        state <= DIGIT_LOOP;
                    end
                end

                CHECK: begin
                    // Calculate MSD of orig_abs
                    // Hardcoded division for synthesis efficiency
                    reg [7:0] msd;
                    if (orig_abs < 10) msd = orig_abs;
                    else if (orig_abs < 100) msd = orig_abs / 10;
                    else msd = orig_abs / 100;

                    if (sign_flag) begin
                        // Negative number: Sum = digit_sum - 2*MSD
                        // Only count if result > 0
                        if (digit_sum > (msd << 1)) begin
                            result <= result + 1;
                        end
                    end else begin
                        // Positive number: Sum = digit_sum
                        if (digit_sum > 0) begin
                            result <= result + 1;
                        end
                    end
                    state <= NEXT;
                end

                NEXT: begin
                    idx <= idx + 1;
                    state <= LOAD;
                end

                FINISH: begin
                    done <= 1;
                    // Stay here until reset
                end
            endcase
        end
    end

endmodule