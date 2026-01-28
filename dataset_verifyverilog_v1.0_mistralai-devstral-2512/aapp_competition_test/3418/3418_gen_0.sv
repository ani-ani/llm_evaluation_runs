module lucky_number_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg [23:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // DP state: dp[pos][rem]
    reg [23:0] dp [0:7] [0:839];
    
    // Precomputed LCMs for n=1..8
    localparam [9:0] LCM [1:8] = '{1, 2, 6, 12, 60, 60, 420, 840};
    
    // Current n value
    reg [3:0] current_n;
    
    // Position counter
    reg [2:0] pos;
    
    // Remainder counter
    reg [9:0] rem;
    
    // Digit counter
    reg [3:0] digit;
    
    // Temporary variables
    reg [23:0] temp_count;
    reg [9:0] new_rem;
    reg [9:0] lcm_val;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize DP array
            integer i, j;
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 840; j = j + 1) begin
                    dp[i][j] <= 24'd0;
                end
            end
            
            pos <= 3'd0;
            rem <= 10'd0;
            digit <= 4'd0;
            current_n <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        state <= COMPUTE;
                        current_n <= n;
                        
                        // Initialize DP[0][0] = 1
                        dp[0][0] <= 24'd1;
                        
                        // Reset position and remainder counters
                        pos <= 3'd0;
                        rem <= 10'd0;
                        digit <= 4'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Get LCM for current n
                    lcm_val <= LCM[current_n];
                    
                    // DP computation loop
                    if (pos < current_n) begin
                        if (rem < lcm_val) begin
                            if (digit < (pos == 3'd0 ? 4'd9 : 4'd10)) begin
                                // Compute new remainder
                                new_rem <= (rem * 10 + digit) % lcm_val;
                                
                                // Update DP for next position
                                temp_count <= dp[pos][rem] + dp[pos][new_rem];
                                
                                // Check for overflow
                                if (temp_count > 24'd16777215) begin
                                    temp_count <= 24'd16777215;
                                end
                                
                                dp[pos][new_rem] <= temp_count;
                                
                                // Increment digit
                                digit <= digit + 4'd1;
                            end else begin
                                digit <= 4'd0;
                                rem <= rem + 10'd1;
                            end
                        end else begin
                            rem <= 10'd0;
                            pos <= pos + 3'd1;
                        end
                    end else begin
                        // Sum all remainders for final position
                        if (rem < lcm_val) begin
                            result <= result + dp[current_n-1][rem];
                            rem <= rem + 10'd1;
                        end else begin
                            state <= FINISH;
                        end
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
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