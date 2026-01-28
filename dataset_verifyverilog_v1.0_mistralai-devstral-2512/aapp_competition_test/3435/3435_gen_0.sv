module PatternCounter(
    input [29:0] pattern,
    input [5:0] n,
    input [5:0] pattern_len,
    output reg [15:0] count,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // DP table: [pos][pat_pos][match_status]
    reg [15:0] dp [0:63][0:63][0:1];
    
    // Internal registers
    reg [5:0] i, j, k;
    reg [15:0] temp_count;
    reg [15:0] total_strings;
    reg [15:0] no_match_count;
    
    always @(*) begin
        // Initialize DP table
        for (i = 0; i <= 63; i = i + 1) begin
            for (j = 0; j <= 63; j = j + 1) begin
                for (k = 0; k <= 1; k = k + 1) begin
                    dp[i][j][k] = 16'd0;
                end
            end
        end
        
        // Base case: empty string and empty pattern
        dp[0][0][1] = 16'd1;
        
        // Fill DP table
        for (i = 0; i < n; i = i + 1) begin
            for (j = 0; j <= pattern_len; j = j + 1) begin
                for (k = 0; k <= 1; k = k + 1) begin
                    if (dp[i][j][k] != 16'd0) begin
                        // Case 1: Add '0' to string
                        if (k == 1'b1) begin
                            // Currently matching, check if we can continue
                            if (j < pattern_len) begin
                                if (pattern[j] == 1'b1) begin
                                    // Pattern requires '1', but we added '0' - no match
                                    dp[i+1][j+1][1'b0] = (dp[i+1][j+1][1'b0] + dp[i][j][k]) % 16'd65535;
                                end else begin
                                    // Pattern has '*', can match anything
                                    dp[i+1][j+1][1'b1] = (dp[i+1][j+1][1'b1] + dp[i][j][k]) % 16'd65535;
                                end
                            end else begin
                                // Pattern fully matched
                                dp[i+1][j][1'b1] = (dp[i+1][j][1'b1] + dp[i][j][k]) % 16'd65535;
                            end
                        end else begin
                            // Not currently matching, stay not matching
                            dp[i+1][j][1'b0] = (dp[i+1][j][1'b0] + dp[i][j][k]) % 16'd65535;
                        end
                        
                        // Case 2: Add '1' to string
                        if (k == 1'b1) begin
                            // Currently matching, check if we can continue
                            if (j < pattern_len) begin
                                if (pattern[j] == 1'b1 || pattern[j] == 1'b0) begin
                                    // Pattern requires '1' or '*', we added '1' - match continues
                                    dp[i+1][j+1][1'b1] = (dp[i+1][j+1][1'b1] + dp[i][j][k]) % 16'd65535;
                                end else begin
                                    // Pattern requires '0', but we added '1' - no match
                                    dp[i+1][j+1][1'b0] = (dp[i+1][j+1][1'b0] + dp[i][j][k]) % 16'd65535;
                                end
                            end else begin
                                // Pattern fully matched
                                dp[i+1][j][1'b1] = (dp[i+1][j][1'b1] + dp[i][j][k]) % 16'd65535;
                            end
                        end else begin
                            // Not currently matching, check if we can start matching
                            if (pattern[0] == 1'b1 || pattern[0] == 1'b0) begin
                                // Pattern starts with '1' or '*', we added '1' - start matching
                                dp[i+1][1][1'b1] = (dp[i+1][1][1'b1] + dp[i][j][k]) % 16'd65535;
                            end else begin
                                // Pattern starts with '0', but we added '1' - stay not matching
                                dp[i+1][j][1'b0] = (dp[i+1][j][1'b0] + dp[i][j][k]) % 16'd65535;
                            end
                        end
                    end
                end
            end
        end
        
        // Calculate total count of strings with at least one match
        temp_count = 16'd0;
        for (j = 0; j <= pattern_len; j = j + 1) begin
            temp_count = (temp_count + dp[n][j][1'b1]) % 16'd65535;
        end
        
        // Total possible strings: 2^n mod 65535
        total_strings = 16'd1;
        for (i = 0; i < n; i = i + 1) begin
            total_strings = (total_strings * 16'd2) % 16'd65535;
        end
        
        // Count strings with no match (approximation)
        no_match_count = (total_strings - temp_count) % 16'd65535;
        
        // Final result: strings with at least one match
        count = temp_count;
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    state <= COMPUTE;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if pattern length is valid
                    if (pattern_len > n) begin
                        count <= 16'd0;
                        state <= FINISH;
                    end else if (pattern_len == 6'd0) begin
                        // Empty pattern matches everything
                        count <= 16'd1;
                        state <= FINISH;
                    end else begin
                        // Perform computation
                        // The combinational block above handles the actual computation
                        state <= FINISH;
                    end
                    
                    // Exit conditions
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