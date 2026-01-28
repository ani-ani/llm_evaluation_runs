module matrix_chain_scheduler (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] sym_count,
    input wire [23:0] assembly_table [7:0][7:0],
    input wire [2:0] string_len,
    input wire [2:0] string_chars [7:0],
    output reg [19:0] result_time,
    output reg [2:0] result_type,
    output reg done
);

    // DP table: dp[i][j][t] - min time to reduce substring i..j to type t
    // i,j: 0-7, t: 0-7
    reg [19:0] dp [7:0][7:0][7:0];
    
    // FSM states
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT_DP    = 3'd1;
    localparam [2:0] COMPUTE_LEN = 3'd2;
    localparam [2:0] FIND_MIN   = 3'd3;
    localparam [2:0] FINISH     = 3'd4;
    
    reg [2:0] state;
    reg [2:0] len_idx;           // Current substring length
    reg [2:0] i_idx, j_idx;      // Start and end indices
    reg [2:0] split_idx;         // Split point
    reg [2:0] type_a, type_b;    // Types from left and right substrings
    reg [2:0] min_type;          // For finding minimum result
    reg [19:0] min_time;         // For finding minimum time
    reg [2:0] cycle_count;       // To prevent infinite loops
    
    // Extract assembly table entries
    wire [19:0] asm_time;
    wire [2:0] asm_result;
    assign asm_time = assembly_table[type_a][type_b][22:3];
    assign asm_result = assembly_table[type_a][type_b][2:0];
    
    // Internal signals for DP computation
    reg [19:0] left_time, right_time, total_time;
    reg [19:0] candidate_time;
    reg [2:0] candidate_type;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all DP entries to max value (infinity)
            for (i_idx = 0; i_idx < 8; i_idx = i_idx + 1) begin
                for (j_idx = 0; j_idx < 8; j_idx = j_idx + 1) begin
                    for (type_a = 0; type_a < 8; type_a = type_a + 1) begin
                        dp[i_idx][j_idx][type_a] <= 20'd1_048_575; // 2^20 - 1 (max 20-bit)
                    end
                end
            end
            
            state <= IDLE;
            result_time <= 20'd0;
            result_type <= 3'd0;
            done <= 1'b0;
            
            len_idx <= 3'd0;
            i_idx <= 3'd0;
            j_idx <= 3'd0;
            split_idx <= 3'd0;
            type_a <= 3'd0;
            type_b <= 3'd0;
            min_type <= 3'd0;
            min_time <= 20'd1_048_575;
            cycle_count <= 3'd0;
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize for length 1 (base case)
                        state <= INIT_DP;
                        len_idx <= 3'd0; // Will be incremented to 0 then 1
                        cycle_count <= 3'd0;
                    end
                end
                
                INIT_DP: begin
                    // Base case: single character substrings
                    if (len_idx < string_len) begin
                        // Each character can be its own type
                        // The time to produce itself is 0 (already that type)
                        // Find all possible assembly rules that produce this type
                        for (type_a = 0; type_a < sym_count; type_a = type_a + 1) begin
                            for (type_b = 0; type_b < sym_count; type_b = type_b + 1) begin
                                if (asm_result == string_chars[len_idx]) begin
                                    // We can produce this from other types, but for base case
                                    // we assume the character itself has 0 cost
                                end
                            end
                        end
                        
                        // For length 1, we can consider the character itself as any type
                        // that can be produced with minimal cost
                        // For simplicity, we set time to 0 for the exact type
                        dp[len_idx][len_idx][string_chars[len_idx]] <= 20'd0;
                        
                        len_idx <= len_idx + 3'd1;
                    end else begin
                        state <= COMPUTE_LEN;
                        len_idx <= 3'd2; // Start with length 2
                        i_idx <= 3'd0;
                        split_idx <= 3'd0;
                        type_a <= 3'd0;
                        type_b <= 3'd0;
                        cycle_count <= 3'd0;
                    end
                end
                
                COMPUTE_LEN: begin
                    // Main DP computation
                    if (len_idx <= string_len && len_idx >= 3'd2) begin
                        // Check if we're within string bounds
                        if (i_idx <= (string_len - len_idx)) begin
                            j_idx <= i_idx + len_idx - 3'd1;
                            
                            // Try all split points
                            if (split_idx < (len_idx - 3'd1)) begin
                                // Try all possible type combinations
                                if (type_a < sym_count) begin
                                    if (type_b < sym_count) begin
                                        // Check if left and right substrings can produce types a and b
                                        left_time = dp[i_idx][i_idx + split_idx][type_a];
                                        right_time = dp[i_idx + split_idx + 3'd1][j_idx][type_b];
                                        
                                        // Check for valid computation (not infinity)
                                        if (left_time < 20'd1_048_575 && right_time < 20'd1_048_575) begin
                                            candidate_time = left_time + right_time + asm_time;
                                            candidate_type = asm_result;
                                            
                                            // Update dp[i][j][candidate_type] if better
                                            if (candidate_time < dp[i_idx][j_idx][candidate_type]) begin
                                                dp[i_idx][j_idx][candidate_type] <= candidate_time;
                                            end else if (candidate_time == dp[i_idx][j_idx][candidate_type]) begin
                                                // Tie-breaker: smaller type index (lower priority)
                                                if (candidate_type < dp[i_idx][j_idx][candidate_type]) begin
                                                    // Already same type, no change needed
                                                end
                                            end
                                        end
                                        
                                        type_b <= type_b + 3'd1;
                                    end else begin
                                        type_b <= 3'd0;
                                        type_a <= type_a + 3'd1;
                                    end
                                end else begin
                                    type_a <= 3'd0;
                                    split_idx <= split_idx + 3'd1;
                                end
                            end else begin
                                // Move to next i
                                split_idx <= 3'd0;
                                type_a <= 3'd0;
                                type_b <= 3'd0;
                                i_idx <= i_idx + 3'd1;
                            end
                        end else begin
                            // Done with this length
                            len_idx <= len_idx + 3'd1;
                            i_idx <= 3'd0;
                            split_idx <= 3'd0;
                            type_a <= 3'd0;
                            type_b <= 3'd0;
                            cycle_count <= cycle_count + 3'd1;
                            
                            // Safety check: limit cycles
                            if (cycle_count >= 3'd7 || len_idx > string_len) begin
                                state <= FIND_MIN;
                                min_time <= 20'd1_048_575;
                                min_type <= 3'd0;
                                type_a <= 3'd0;
                            end
                        end
                    end else begin
                        state <= FIND_MIN;
                        min_time <= 20'd1_048_575;
                        min_type <= 3'd0;
                        type_a <= 3'd0;
                    end
                end
                
                FIND_MIN: begin
                    // Find minimum time across all types for dp[0][string_len-1][t]
                    if (type_a < sym_count) begin
                        if (dp[3'd0][string_len - 3'd1][type_a] < min_time) begin
                            min_time <= dp[3'd0][string_len - 3'd1][type_a];
                            min_type <= type_a;
                        end else if (dp[3'd0][string_len - 3'd1][type_a] == min_time) begin
                            // Tie-breaker: prefer smaller type index
                            if (type_a < min_type) begin
                                min_type <= type_a;
                            end
                        end
                        type_a <= type_a + 3'd1;
                    end else begin
                        state <= FINISH;
                        result_time <= min_time;
                        result_type <= min_type;
                        done <= 1'b1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule