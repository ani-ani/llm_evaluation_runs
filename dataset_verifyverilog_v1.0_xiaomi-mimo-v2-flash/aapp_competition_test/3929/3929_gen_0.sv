module deque_seq (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n_in,
    input wire [4:0] k_in,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] DONE_STATE = 3'd2;

    // State machine
    reg [2:0] state;
    reg [2:0] next_state;

    // Input registers
    reg [4:0] N_reg;
    reg [4:0] K_reg;

    // DP table: K x N, max 16x16 = 256 entries
    reg [31:0] dp [0:15][0:15]; // dp[i][j], i from 0..15, j from 0..15

    // Iteration counters
    reg [4:0] i_cnt; // 0..15
    reg [4:0] j_cnt; // 0..15

    // Internal computation signals
    reg [31:0] temp_sum;
    reg [31:0] temp_sub;
    reg [63:0] calc_temp; // For multiplication

    // Control flags
    reg computing_done;

    // Reset and state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            N_reg <= 5'd0;
            K_reg <= 5'd0;
            i_cnt <= 5'd0;
            j_cnt <= 5'd0;
            computing_done <= 1'b0;
            // Initialize dp table
            for (int r = 0; r < 16; r = r + 1) begin
                for (int c = 0; c < 16; c = c + 1) begin
                    dp[r][c] <= 32'd0;
                end
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    i_cnt <= 5'd0;
                    j_cnt <= 5'd0;
                    computing_done <= 1'b0;
                    if (start) begin
                        N_reg <= n_in;
                        K_reg <= k_in;
                        // Initialize dp table for IDLE
                        for (int r = 0; r < 16; r = r + 1) begin
                            for (int c = 0; c < 16; c = c + 1) begin
                                dp[r][c] <= 32'd0;
                            end
                        end
                    end
                end

                COMPUTE: begin
                    // DP Computation Logic
                    // Recurrence: dp[i][j] = (dp[i-1][j] + prefix_sum[N] - prefix_sum[j]) % MOD
                    // Logic: prefix_sum[0] = 0, prefix_sum[x] = x*(x+1)/2
                    // dp[i][j] depends on dp[i-1][x] for x < j
                    // We iterate i from 1 to K-1
                    // We iterate j from 2 to N
                    
                    // Start indices check
                    if (i_cnt == 5'd0) begin
                        i_cnt <= 5'd1;
                        j_cnt <= 5'd2;
                    end else if (i_cnt < K_reg) begin
                        if (j_cnt <= N_reg) begin
                            // Calculate prefix sums on the fly
                            // prefix_sum[N] = N*(N+1)/2
                            // prefix_sum[j] = j*(j+1)/2
                            
                            // Compute sum_N = N*(N+1)/2 % MOD
                            // Compute sum_j = j*(j+1)/2 % MOD
                            // Compute diff = (sum_N - sum_j) % MOD
                            // Note: We need dp[i-1][j] (which is dp[i_cnt-1][j_cnt])
                            // The recurrence describes sum over lengths of prefix taken from first K items
                            // dp[i][j] = sum_{x=j}^{N} dp[i-1][x]
                            // This is equivalent to dp[i][j] = dp[i][j-1] + dp[i-1][j]
                            // Let's use the standard sum recurrence to be safe for boundaries
                            
                            // Wait, the description says: dp[i][j] = (dp[i-1][j] + prefix_sum[N] - prefix_sum[j]) % MOD
                            // Let's re-verify logic. Standard deque DP:
                            // dp[i][j] = dp[i][j+1] + dp[i-1][j] (if we treat i as length)
                            // Let's stick to the provided formula but verify if 'prefix_sum' implies sum of indices or just a helper.
                            // Given "prefix_sum[N] - prefix_sum[j]", if prefix_sum[x] = x*(x+1)/2, it's sum of 1..x.
                            // This seems like a specific counting. Let's use the provided formula directly.
                            
                            // Step 1: Calculate Prefix Sum of N
                            calc_temp = N_reg * (N_reg + 1'b1);
                            temp_sum = calc_temp >> 1; // Divide by 2
                            
                            // Step 2: Calculate Prefix Sum of j
                            calc_temp = j_cnt * (j_cnt + 1'b1);
                            temp_sub = calc_temp >> 1;
                            
                            // Step 3: Diff = Sum_N - Sum_j
                            if (temp_sum >= temp_sub)
                                temp_sub = temp_sum - temp_sub;
                            else
                                temp_sub = MOD + temp_sum - temp_sub;
                            
                            // Step 4: Add dp[i-1][j]
                            temp_sub = temp_sub + dp[i_cnt - 1'b1][j_cnt];
                            if (temp_sub >= MOD) temp_sub = temp_sub - MOD;
                            
                            // Store result
                            dp[i_cnt][j_cnt] <= temp_sub;
                            
                            // Increment j
                            j_cnt <= j_cnt + 1'b1;
                        end else begin
                            // Done with current i, move to next i
                            i_cnt <= i_cnt + 1'b1;
                            j_cnt <= 5'd2;
                        end
                    end else begin
                        // Computation finished for all i=1..K-1
                        computing_done <= 1'b1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    // Result is dp[K-1][N]
                    // Handle case K=1: result is 1 (only one way)
                    if (K_reg == 5'd1) begin
                        result <= 32'd1;
                    end else begin
                        result <= dp[K_reg - 1'b1][N_reg];
                    end
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    // If K=1, it's a trivial case, can go directly to DONE if needed, 
                    // but let's go to COMPUTE to handle generally or jump if trivial.
                    // The DP loop runs for i=1 to K-1. If K=1, loop range is empty.
                    // We can handle K=1 in IDLE->DONE, but let's keep flow simple.
                    // If K > 1, COMPUTE is needed.
                    next_state = COMPUTE;
                end
            end
            COMPUTE: begin
                // Check if done
                if (computing_done) begin
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule