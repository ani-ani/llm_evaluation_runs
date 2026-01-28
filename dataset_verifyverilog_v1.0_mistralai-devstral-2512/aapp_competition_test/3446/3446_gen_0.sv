module AssemblyScheduler(
    input clk,
    input rst_n,
    input start,
    input [2:0] sym_count,
    input [7:0][7:0][23:0] assembly_table,
    input [2:0] string_len,
    input [7:0][2:0] string_chars,
    output reg [19:0] result_time,
    output reg [2:0] result_type,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // DP table: dp[i][j][t] for i,j in 0-7, t in 0-7
    reg [19:0] dp [0:7][0:7][0:7];
    reg [2:0] result_symbol [0:7][0:7][0:7];
    
    // Current computation indices
    reg [2:0] i_reg, j_reg, t_reg, k_reg;
    reg [2:0] split_reg;
    reg [19:0] min_time;
    reg [2:0] min_type;
    reg [2:0] current_len;
    reg [2:0] current_start;
    reg [19:0] temp_time;
    reg [2:0] temp_type;
    reg [19:0] assembly_time;
    reg [2:0] assembly_result;
    
    // Initialize DP table
    integer idx, jdx, tdx;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_time <= 20'd0;
            result_type <= 3'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize DP table to max value
            for (idx = 0; idx < 8; idx = idx + 1) begin
                for (jdx = 0; jdx < 8; jdx = jdx + 1) begin
                    for (tdx = 0; tdx < 8; tdx = tdx + 1) begin
                        dp[idx][jdx][tdx] <= 20'd1000000;
                        result_symbol[idx][jdx][tdx] <= 3'd0;
                    end
                end
            end
            
            i_reg <= 3'd0;
            j_reg <= 3'd0;
            t_reg <= 3'd0;
            k_reg <= 3'd0;
            split_reg <= 3'd0;
            current_len <= 3'd0;
            current_start <= 3'd0;
            min_time <= 20'd0;
            min_type <= 3'd0;
            temp_time <= 20'd0;
            temp_type <= 3'd0;
            assembly_time <= 20'd0;
            assembly_result <= 3'd0;
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Initialize base cases (single characters)
                    for (idx = 0; idx < string_len; idx = idx + 1) begin
                        for (tdx = 0; tdx < sym_count; tdx = tdx + 1) begin
                            if (string_chars[idx] == tdx) begin
                                dp[idx][idx][tdx] <= 20'd0;
                                result_symbol[idx][idx][tdx] <= tdx;
                            end else begin
                                dp[idx][idx][tdx] <= 20'd1000000;
                                result_symbol[idx][idx][tdx] <= 3'd0;
                            end
                        end
                    end
                    
                    current_len <= 3'd1;  // Start with length 1
                    current_start <= 3'd0;
                    state <= COMPUTE;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all lengths
                    if (current_len == string_len) begin
                        state <= FINISH;
                    end else begin
                        // Process all substrings of current length
                        if (current_start + current_len <= string_len) begin
                            i_reg <= current_start;
                            j_reg <= current_start + current_len;
                            
                            // Initialize min values for this i,j
                            min_time <= 20'd1000000;
                            min_type <= 3'd0;
                            
                            // Try all split points k between i and j-1
                            for (k_reg = i_reg; k_reg < j_reg; k_reg = k_reg + 1) begin
                                // Try all possible symbol types for left and right
                                for (split_reg = 0; split_reg < sym_count; split_reg = split_reg + 1) begin
                                    for (t_reg = 0; t_reg < sym_count; t_reg = t_reg + 1) begin
                                        // Get assembly time and result
                                        assembly_time <= assembly_table[split_reg][t_reg][23:3];
                                        assembly_result <= assembly_table[split_reg][t_reg][2:0];
                                        
                                        // Calculate total time
                                        temp_time <= dp[i_reg][k_reg][split_reg] + 
                                                    dp[k_reg + 1][j_reg][t_reg] + 
                                                    assembly_time;
                                        
                                        // Update if better
                                        if (temp_time < min_time || 
                                            (temp_time == min_time && assembly_result < min_type)) begin
                                            min_time <= temp_time;
                                            min_type <= assembly_result;
                                        end
                                    end
                                end
                            end
                            
                            // Store result for this i,j
                            for (t_reg = 0; t_reg < sym_count; t_reg = t_reg + 1) begin
                                if (t_reg == min_type) begin
                                    dp[i_reg][j_reg][t_reg] <= min_time;
                                    result_symbol[i_reg][j_reg][t_reg] <= min_type;
                                end
                            end
                            
                            // Move to next substring
                            current_start <= current_start + 1'b1;
                        end else begin
                            // Move to next length
                            current_len <= current_len + 1'b1;
                            current_start <= 3'd0;
                        end
                    end
                    
                    // Safety check for max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Find minimum time across all types for full string
                    min_time <= 20'd1000000;
                    min_type <= 3'd0;
                    
                    for (t_reg = 0; t_reg < sym_count; t_reg = t_reg + 1) begin
                        if (dp[0][string_len - 1][t_reg] < min_time ||
                            (dp[0][string_len - 1][t_reg] == min_time && t_reg < min_type)) begin
                            min_time <= dp[0][string_len - 1][t_reg];
                            min_type <= t_reg;
                        end
                    end
                    
                    result_time <= min_time;
                    result_type <= min_type;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
endmodule