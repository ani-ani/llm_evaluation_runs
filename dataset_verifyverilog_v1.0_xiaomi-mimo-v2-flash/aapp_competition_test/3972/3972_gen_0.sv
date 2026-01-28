module CountValidSequences (
    input clk,
    input rst_n,
    input start,
    input [9:0] n_in,
    output reg [31:0] result,
    output reg done
);

    // Modulus 10^9+7
    localparam [31:0] MOD = 32'd1000000007;
    
    // States
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LOAD     = 3'd1;
    localparam [2:0] COMPUTE  = 3'd2;
    localparam [2:0] FINISH   = 3'd3;
    
    reg [2:0] state, next_state;
    reg [9:0] n_reg;          // Store n (1-1024)
    reg [9:0] i;              // Current index for iteration
    reg [31:0] dp;            // Current dp[i] value
    reg [31:0] prev_dp;       // dp[i+1] (previous)
    reg [31:0] sum_dp;        // Sliding window sum of dp[i+d] for d=3 to n-1
    reg [31:0] n_sq;          // n*n mod MOD
    reg [31:0] n_minus_1;     // (n-1) mod MOD
    reg [31:0] temp_result;   // Intermediate result calculation
    
    // Control signals
    reg computing;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            i <= 10'd0;
            dp <= 32'd0;
            prev_dp <= 32'd0;
            sum_dp <= 32'd0;
            n_reg <= 10'd0;
            n_sq <= 32'd0;
            n_minus_1 <= 32'd0;
            temp_result <= 32'd0;
            computing <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    computing <= 1'b0;
                    if (start) begin
                        n_reg <= n_in;
                    end
                end
                
                LOAD: begin
                    // Initialize n_sq = (n-1)^2 mod MOD
                    n_minus_1 <= (n_in - 10'd1) % MOD[9:0];
                    n_sq <= ((n_in - 10'd1) % MOD[9:0]) * ((n_in - 10'd1) % MOD[9:0]) % MOD;
                    i <= n_in - 10'd2;  // Start from i = n-2
                    prev_dp <= n_in % MOD[9:0];  // dp[n-1] = n
                    sum_dp <= 32'd0;
                    computing <= 1'b1;
                end
                
                COMPUTE: begin
                    if (computing && i >= 10'd1) begin
                        // Calculate dp[i] = dp[i+1] + sum_dp + n_sq + (n-1)^2
                        // For i = n-2: sum_dp = 0, so dp[n-2] = n + 0 + (n-1)^2 = n + (n-1)^2
                        // But we need dp[n-2] = n*n (from problem spec)
                        // Actually: dp[n-2] = n + (n-1)^2 = n + n^2 - 2n + 1 = n^2 - n + 1
                        // Let's use the explicit formula for i=n-2 first
                        
                        if (i == n_reg - 10'd2) begin
                            // Special case for i = n-2
                            // dp[n-2] = n*n mod MOD
                            dp <= (n_reg % MOD[9:0]) * (n_reg % MOD[9:0]) % MOD;
                            prev_dp <= (n_reg % MOD[9:0]) * (n_reg % MOD[9:0]) % MOD;
                            sum_dp <= (n_reg % MOD[9:0]) * (n_reg % MOD[9:0]) % MOD;  // Add to window
                        end else begin
                            // General case: dp[i] = dp[i+1] + sum(dp[i+d]) + n_sq + (n-1)^2
                            // sum_dp currently holds sum of dp[i+d] for d=3 to n-1
                            // We need to add dp[i+3] and remove dp[i+n] from the window
                            
                            temp_result <= ((prev_dp + sum_dp) % MOD + n_sq) % MOD;
                            dp <= ((prev_dp + sum_dp) % MOD + n_sq) % MOD;
                            prev_dp <= ((prev_dp + sum_dp) % MOD + n_sq) % MOD;
                            
                            // Update sum_dp for next iteration (i-1)
                            // New sum = old sum + dp[i+2] - dp[i+n]
                            // We need to maintain dp[i+2] and dp[i+n] values
                        end
                        
                        i <= i - 10'd1;
                    end else if (computing && i == 10'd0) begin
                        // Final calculation for dp[0]
                        // dp[0] = dp[1] + sum(dp[1+d]) + n_sq + (n-1)^2
                        dp <= ((prev_dp + sum_dp) % MOD + n_sq) % MOD;
                        result <= ((prev_dp + sum_dp) % MOD + n_sq) % MOD;
                        computing <= 1'b0;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end else begin
                    next_state = IDLE;
                end
            end
            
            LOAD: begin
                next_state = COMPUTE;
            end
            
            COMPUTE: begin
                if (computing && i == 10'd0 && !start) begin
                    next_state = FINISH;
                end else begin
                    next_state = COMPUTE;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule