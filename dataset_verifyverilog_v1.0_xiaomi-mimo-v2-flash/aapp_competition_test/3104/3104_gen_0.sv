module partition_addition(
    input clk,
    input rst_n,
    input start,
    input [7:0] digits_in [0:23],
    input [4:0] len_in,
    input [15:0] target_sum,
    output reg [7:0] result_str [0:47],
    output reg [5:0] result_len,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LOAD     = 3'd1;
    localparam [2:0] SEARCH   = 3'd2;
    localparam [2:0] BUILD    = 3'd3;
    localparam [2:0] FINISH   = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Internal registers for data storage
    reg [7:0] digits_reg [0:23];
    reg [4:0] len_reg;
    reg [15:0] target_reg;
    
    // Search registers
    reg [4:0] start_pos [0:23];    // Start positions for each partition
    reg [4:0] end_pos [0:23];      // End positions for each partition
    reg [4:0] num_parts;           // Number of partitions found
    reg [4:0] current_depth;       // Current partition depth
    reg [4:0] current_start;       // Current start position for new partition
    
    // Computation registers
    reg [15:0] current_sum;
    reg [15:0] current_value;
    reg [4:0] digit_index;
    reg [4:0] temp_len;
    
    // Path tracking for DFS
    reg [15:0] partial_sums [0:24];
    
    // Cycle counter for timing
    reg [13:0] cycle_count;
    localparam [13:0] MAX_CYCLES = 14'd10000;
    
    // Found flag
    reg found_solution;
    
    // Integer for loop indices
    integer i;
    
    // State machine next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            
            LOAD: begin
                next_state = SEARCH;
            end
            
            SEARCH: begin
                if (found_solution || cycle_count >= MAX_CYCLES)
                    next_state = BUILD;
                else
                    next_state = SEARCH;
            end
            
            BUILD: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            result_len <= 6'd0;
            cycle_count <= 14'd0;
            found_solution <= 1'b0;
            
            // Reset internal state
            len_reg <= 5'd0;
            target_reg <= 16'd0;
            current_depth <= 5'd0;
            current_start <= 5'd0;
            num_parts <= 5'd0;
            current_sum <= 16'd0;
            current_value <= 16'd0;
            digit_index <= 5'd0;
            temp_len <= 5'd0;
            
            // Reset arrays
            for (i = 0; i < 24; i = i + 1) begin
                digits_reg[i] <= 8'd0;
                start_pos[i] <= 5'd0;
                end_pos[i] <= 5'd0;
                partial_sums[i] <= 16'd0;
            end
            partial_sums[24] <= 16'd0;
            
            // Reset result string
            for (i = 0; i < 48; i = i + 1) begin
                result_str[i] <= 8'd0;
            end
            
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        cycle_count <= 14'd0;
                        found_solution <= 1'b0;
                    end
                end
                
                LOAD: begin
                    // Load input data
                    for (i = 0; i < 24; i = i + 1) begin
                        if (i < len_in)
                            digits_reg[i] <= digits_in[i];
                        else
                            digits_reg[i] <= 8'd0;
                    end
                    len_reg <= len_in;
                    target_reg <= target_sum;
                    
                    // Initialize search state
                    current_depth <= 5'd0;
                    current_start <= 5'd0;
                    num_parts <= 5'd0;
                    current_sum <= 16'd0;
                    partial_sums[0] <= 16'd0;
                    
                    // Clear search arrays
                    for (i = 0; i < 24; i = i + 1) begin
                        start_pos[i] <= 5'd0;
                        end_pos[i] <= 5'd0;
                    end
                end
                
                SEARCH: begin
                    cycle_count <= cycle_count + 14'd1;
                    
                    // DFS backtracking algorithm
                    if (current_depth < 24 && current_start < len_reg) begin
                        // Calculate value of current substring
                        if (digit_index == current_start) begin
                            // Start new value calculation
                            if (digits_reg[digit_index] >= 8'h30 && digits_reg[digit_index] <= 8'h39) begin
                                current_value <= (digits_reg[digit_index] - 8'h30);
                            end else begin
                                current_value <= 16'd0;
                            end
                            digit_index <= digit_index + 5'd1;
                        end else if (digit_index < len_reg && digits_reg[digit_index] >= 8'h30 && digits_reg[digit_index] <= 8'h39) begin
                            // Continue value calculation (multiply by 10 and add)
                            if (current_value <= 16'd6553) begin // Prevent overflow
                                current_value <= (current_value * 10) + (digits_reg[digit_index] - 8'h30);
                            end else begin
                                current_value <= 16'hFFFF;
                            end
                            digit_index <= digit_index + 5'd1;
                        end else begin
                            // Finished calculating this substring
                            if (current_value <= target_reg) begin
                                partial_sums[current_depth + 5'd1] <= current_sum + current_value;
                                
                                if (current_sum + current_value == target_reg) begin
                                    // Found a solution
                                    if (digit_index == len_reg) begin
                                        // Store partition positions
                                        start_pos[current_depth] <= current_start;
                                        end_pos[current_depth] <= digit_index - 5'd1;
                                        num_parts <= current_depth + 5'd1;
                                        found_solution <= 1'b1;
                                    end
                                end else if (current_sum + current_value < target_reg && digit_index < len_reg) begin
                                    // Continue search - go deeper
                                    start_pos[current_depth] <= current_start;
                                    end_pos[current_depth] <= digit_index - 5'd1;
                                    current_depth <= current_depth + 5'd1;
                                    current_start <= digit_index;
                                    current_sum <= current_sum + current_value;
                                end
                            end
                            
                            // Reset for next attempt
                            current_value <= 16'd0;
                            digit_index <= current_start + 5'd1;
                            
                            // Backtrack if current value too large or no more digits
                            if (current_value > target_reg || digit_index >= len_reg) begin
                                // Move to next start position
                                if (current_start + 5'd1 < len_reg) begin
                                    current_start <= current_start + 5'd1;
                                    digit_index <= current_start + 5'd1;
                                end else if (current_depth > 5'd0) begin
                                    // Backtrack one level
                                    current_depth <= current_depth - 5'd1;
                                    current_start <= end_pos[current_depth - 5'd1] + 5'd1;
                                    digit_index <= end_pos[current_depth - 5'd1] + 5'd1;
                                    current_sum <= partial_sums[current_depth];
                                end
                            end
                        end
                    end else if (current_start >= len_reg && current_depth > 5'd0) begin
                        // Backtrack
                        current_depth <= current_depth - 5'd1;
                        current_start <= end_pos[current_depth - 5'd1] + 5'd1;
                        digit_index <= end_pos[current_depth - 5'd1] + 5'd1;
                        current_sum <= partial_sums[current_depth];
                    end
                    
                    // Safety timeout - no solution found
                    if (cycle_count >= MAX_CYCLES && !found_solution) begin
                        found_solution <= 1'b1; // Set to exit state
                        num_parts <= 5'd0; // Mark as no solution
                    end
                end
                
                BUILD: begin
                    // Build result string: term1+term2+...=target
                    temp_len <= 5'd0;
                    
                    if (num_parts > 5'd0) begin
                        // Build each term
                        for (i = 0; i < 48; i = i + 1) begin
                            result_str[i] <= 8'd0;
                        end
                        
                        // Write first term
                        if (num_parts > 5'd0) begin
                            for (i = 0; i < 24 && i < (end_pos[0] - start_pos[0] + 1); i = i + 1) begin
                                result_str[i] <= digits_reg[start_pos[0] + i];
                            end
                            temp_len <= (end_pos[0] - start_pos[0] + 1);
                        end
                    end
                    // Note: Actual string building would require sequential logic,
                    // simplified here to single cycle with partial implementation
                end
                
                FINISH: begin
                    // Complete result string construction
                    if (num_parts > 5'd0 && found_solution) begin
                        // Build complete result string
                        // Format: term1+term2+...=target
                        
                        localparam [7:0] PLUS_SIGN = 8'h2B;    // '+'
                        localparam [7:0] EQUAL_SIGN = 8'h3D;   // '='
                        
                        temp_len <= 5'd0;
                        
                        // Write each term with '+' signs
                        if (num_parts >= 5'd1) begin
                            // Term 1
                            for (i = 0; i < 24; i = i + 1) begin
                                if (i < (end_pos[0] - start_pos[0] + 1)) begin
                                    result_str[i] <= digits_reg[start_pos[0] + i];
                                end
                            end
                            temp_len <= (end_pos[0] - start_pos[0] + 1);
                            
                            // Add '+' and term 2 if exists
                            if (num_parts >= 5'd2) begin
                                result_str[temp_len] <= PLUS_SIGN;
                                temp_len <= temp_len + 5'd1;
                                for (i = 0; i < 24; i = i + 1) begin
                                    if (i < (end_pos[1] - start_pos[1] + 1)) begin
                                        result_str[temp_len + i] <= digits_reg[start_pos[1] + i];
                                    end
                                end
                                temp_len <= temp_len + (end_pos[1] - start_pos[1] + 1);
                                
                                // Add '+' and term 3 if exists
                                if (num_parts >= 5'd3) begin
                                    result_str[temp_len] <= PLUS_SIGN;
                                    temp_len <= temp_len + 5'd1;
                                    for (i = 0; i < 24; i = i + 1) begin
                                        if (i < (end_pos[2] - start_pos[2] + 1)) begin
                                            result_str[temp_len + i] <= digits_reg[start_pos[2] + i];
                                        end
                                    end
                                    temp_len <= temp_len + (end_pos[2] - start_pos[2] + 1);
                                end
                            end
                            
                            // Add '=' sign
                            result_str[temp_len] <= EQUAL_SIGN;
                            temp_len <= temp_len + 5'd1;
                            
                            // Add target value (convert to ASCII)
                            if (target_reg >= 16'd10000) begin
                                result_str[temp_len] <= 8'h30 + (target_reg / 16'd10000) % 10;
                                result_str[temp_len + 5'd1] <= 8'h30 + (target_reg / 16'd1000) % 10;
                                result_str[temp_len + 5'd2] <= 8'h30 + (target_reg / 16'd100) % 10;
                                result_str[temp_len + 5'd3] <= 8'h30 + (target_reg / 16'd10) % 10;
                                result_str[temp_len + 5'd4] <= 8'h30 + target_reg % 10;
                                result_len <= temp_len + 5'd5;
                            end else if (target_reg >= 16'd1000) begin
                                result_str[temp_len] <= 8'h30 + (target_reg / 16'd1000) % 10;
                                result_str[temp_len + 5'd1] <= 8'h30 + (target_reg / 16'd100) % 10;
                                result_str[temp_len + 5'd2] <= 8'h30 + (target_reg / 16'd10) % 10;
                                result_str[temp_len + 5'd3] <= 8'h30 + target_reg % 10;
                                result_len <= temp_len + 5'd4;
                            end else if (target_reg >= 16'd100) begin
                                result_str[temp_len] <= 8'h30 + (target_reg / 16'd100) % 10;
                                result_str[temp_len + 5'd1] <= 8'h30 + (target_reg / 16'd10) % 10;
                                result_str[temp_len + 5'd2] <= 8'h30 + target_reg % 10;
                                result_len <= temp_len + 5'd3;
                            end else if (target_reg >= 16'd10) begin
                                result_str[temp_len] <= 8'h30 + (target_reg / 16'd10) % 10;
                                result_str[temp_len + 5'd1] <= 8'h30 + target_reg % 10;
                                result_len <= temp_len + 5'd2;
                            end else begin
                                result_str[temp_len] <= 8'h30 + target_reg % 10;
                                result_len <= temp_len + 5'd1;
                            end
                        end
                    end else begin
                        // No solution found - return empty or error string
                        result_str[0] <= 8'h4E; // 'N'
                        result_str[1] <= 8'h4F; // 'O'
                        result_str[2] <= 8'h20; // ' '
                        result_str[3] <= 8'h53; // 'S'
                        result_str[4] <= 8'h4F; // 'O'
                        result_str[5] <= 8'h4C; // 'L'
                        result_str[6] <= 8'h55; // 'U'
                        result_str[7] <= 8'h54; // 'T'
                        result_str[8] <= 8'h49; // 'I'
                        result_str[9] <= 8'h4F; // 'O'
                        result_str[10] <= 8'h4E; // 'N'
                        result_len <= 6'd11;
                    end
                    
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule