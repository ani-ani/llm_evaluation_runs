module LargestDivisibleSubset(
    input clk,
    input rst_n,
    input start,
    input [15:0] arr [0:15],
    input [3:0] length,
    output reg [4:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Registers
    reg [1:0] state;
    reg [4:0] dp [0:15];
    reg [3:0] i;
    reg [3:0] j;
    reg [4:0] max_val;
    reg [15:0] temp_dividend;
    reg [15:0] temp_divisor;
    reg [15:0] remainder;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Internal state for computation
    reg [1:0] compute_state;
    localparam [1:0] DIV_INIT = 2'd0;
    localparam [1:0] DIV_RUNNING = 2'd1;
    localparam [1:0] DIV_COMPLETE = 2'd2;

    // Integer for loop indices
    integer idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            result <= 5'd0;
            cycle_count <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            max_val <= 5'd0;
            temp_dividend <= 16'd0;
            temp_divisor <= 16'd0;
            remainder <= 16'd0;
            compute_state <= DIV_INIT;
            for (idx = 0; idx < 16; idx = idx + 1) begin
                dp[idx] <= 5'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    max_val <= 5'd0;
                    compute_state <= DIV_INIT;
                    if (start) begin
                        if (length == 4'd0) begin
                            // Empty array case
                            state <= FINISH;
                            result <= 5'd0;
                        end else begin
                            state <= COMPUTE;
                            // Initialize dp array
                            for (idx = 0; idx < 16; idx = idx + 1) begin
                                if (idx < length) begin
                                    dp[idx] <= 5'd1;
                                end else begin
                                    dp[idx] <= 5'd0;
                                end
                            end
                        end
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Outer loop: i from length-1 down to 0
                    if (i < length) begin
                        // Inner loop: j from i+1 to length-1
                        if (j < length) begin
                            if (j > i) begin
                                // Check divisibility: arr[i] % arr[j] == 0 OR arr[j] % arr[i] == 0
                                case (compute_state)
                                    DIV_INIT: begin
                                        // Check first condition: arr[i] % arr[j] == 0
                                        if (arr[j] != 16'd0) begin
                                            temp_dividend <= arr[i];
                                            temp_divisor <= arr[j];
                                            remainder <= arr[i];
                                            compute_state <= DIV_RUNNING;
                                        end else begin
                                            // arr[j] is 0, skip division
                                            compute_state <= DIV_COMPLETE;
                                        end
                                    end

                                    DIV_RUNNING: begin
                                        // Sequential division for remainder
                                        if (remainder >= temp_divisor) begin
                                            remainder <= remainder - temp_divisor;
                                        end else begin
                                            compute_state <= DIV_COMPLETE;
                                        end
                                    end

                                    DIV_COMPLETE: begin
                                        if (remainder == 16'd0) begin
                                            // arr[i] % arr[j] == 0, update dp[i]
                                            if (dp[j] + 5'd1 > dp[i]) begin
                                                dp[i] <= dp[j] + 5'd1;
                                            end
                                        end else begin
                                            // Check second condition: arr[j] % arr[i] == 0
                                            if (arr[i] != 16'd0) begin
                                                temp_dividend <= arr[j];
                                                temp_divisor <= arr[i];
                                                remainder <= arr[j];
                                                compute_state <= DIV_RUNNING;
                                                // Use a flag to indicate we're on second check
                                                // We'll use the lower bit of remainder as flag
                                                remainder[15] <= 1'b1; // Mark second check
                                            end
                                        end
                                        // After first complete, if we already updated, move to next j
                                        if (compute_state == DIV_COMPLETE && remainder[15] == 1'b0) begin
                                            j <= j + 4'd1;
                                            compute_state <= DIV_INIT;
                                        end
                                        // After second check complete
                                        if (compute_state == DIV_COMPLETE && remainder[15] == 1'b1) begin
                                            remainder[15] <= 1'b0;
                                            if (remainder[14:0] == 15'd0) begin
                                                // arr[j] % arr[i] == 0
                                                if (dp[j] + 5'd1 > dp[i]) begin
                                                    dp[i] <= dp[j] + 5'd1;
                                                end
                                            end
                                            j <= j + 4'd1;
                                            compute_state <= DIV_INIT;
                                        end
                                    end
                                endcase
                            end else begin
                                j <= j + 4'd1;
                            end
                        end else begin
                            // Inner loop complete for this i
                            // Update max_val
                            if (dp[i] > max_val) begin
                                max_val <= dp[i];
                            end
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end else begin
                        // All loops complete
                        state <= FINISH;
                        result <= max_val;
                    end

                    // Safety timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        result <= max_val;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule