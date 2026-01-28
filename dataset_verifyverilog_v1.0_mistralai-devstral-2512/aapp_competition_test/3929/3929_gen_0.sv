module deque_seq(
    input clk,
    input rst_n,
    input start,
    input [4:0] n_in,
    input [4:0] k_in,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam MOD = 32'd1000000007;
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // State and control signals
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // DP table and prefix sum
    reg [31:0] dp [0:15][0:15];
    reg [31:0] prefix_sum [0:15];

    // Loop counters
    reg [4:0] i;
    reg [4:0] j;

    // Temporary variables
    reg [31:0] temp_sum;
    reg [31:0] temp_val;

    // Initialize DP table and prefix sum
    integer idx, jdx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 5'd0;
            j <= 5'd0;
            for (idx = 0; idx < 16; idx = idx + 1) begin
                for (jdx = 0; jdx < 16; jdx = jdx + 1) begin
                    dp[idx][jdx] <= 32'd0;
                end
                prefix_sum[idx] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        // Initialize DP table
                        for (idx = 0; idx < 16; idx = idx + 1) begin
                            for (jdx = 0; jdx < 16; jdx = jdx + 1) begin
                                dp[idx][jdx] <= 32'd0;
                            end
                        end
                        // Base case: dp[0][1] = 1
                        dp[0][1] <= 32'd1;
                        i <= 5'd0;
                        j <= 5'd1;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end else begin
                        if (i < k_in - 1) begin
                            if (j < n_in + 1) begin
                                // Compute prefix sum
                                if (j == 1) begin
                                    prefix_sum[j] <= dp[i][j];
                                end else begin
                                    prefix_sum[j] <= (prefix_sum[j-1] + dp[i][j]) % MOD;
                                end
                                
                                // Update DP table
                                if (j > 1) begin
                                    temp_sum <= (prefix_sum[n_in] - prefix_sum[j-1]) % MOD;
                                    if (temp_sum < 0) begin
                                        temp_sum <= temp_sum + MOD;
                                    end
                                    dp[i+1][j] <= (dp[i][j] + temp_sum) % MOD;
                                end
                                j <= j + 5'd1;
                            end else begin
                                j <= 5'd1;
                                i <= i + 5'd1;
                            end
                        end else begin
                            // Final result
                            result <= dp[k_in-1][n_in];
                            state <= DONE_STATE;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule