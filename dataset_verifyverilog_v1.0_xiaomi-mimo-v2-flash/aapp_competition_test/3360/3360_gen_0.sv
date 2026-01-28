module cfg_search (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [31:0] cfg_rules,
    input wire [3:0] input_len,
    input wire text_mode,
    output reg [3:0] result_start,
    output reg [3:0] result_len,
    output reg done,
    output reg busy
);

// State declarations
localparam [3:0] IDLE          = 4'd0;
localparam [3:0] LOAD_TEXT     = 4'd1;
localparam [3:0] LOAD_RULES    = 4'd2;
localparam [3:0] PARSE_INIT    = 4'd3;
localparam [3:0] PARSE_LOOP    = 4'd4;
localparam [3:0] FIND_BEST     = 4'd5;
localparam [3:0] FINISH        = 4'd6;

// Internal signals
reg [3:0] state, next_state;
reg [7:0] input_buffer [0:15];  // Store input characters
reg [7:0] input_buffer_index;

// CFG Rules storage: 32 bits per rule, 16 rules = 512 bits
reg [31:0] rules [0:15];
reg [3:0] rule_count;
reg [3:0] rule_index;

// CYK-style parsing table: 16x16 x 26 variables (bitmask)
// Using packed array for synthesis efficiency
reg [25:0] parse_table [0:15][0:15];  // 26 bits for variables A-Z

// Parsing indices
reg [3:0] row, col, mid;  // i, j, k indices
reg [3:0] span_len;
reg [25:0] temp_mask;
reg [25:0] new_mask;
reg [25:0] left_mask;
reg [25:0] right_mask;

// Rule parsing
reg [7:0] rule_head;
reg [23:0] rule_body;
reg [7:0] body_char0, body_char1, body_char2;

// Best match tracking
reg [3:0] best_start_temp;
reg [3:0] best_len_temp;
reg [3:0] scan_i, scan_j;

// Cycle counter to prevent infinite loops
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd200;

// Helper functions for character classification
function automatic [5:0] char_to_var(input [7:0] ch);
    // Convert 'A'-'Z' to 0-25, returns 63 for non-variable
    if (ch >= 8'd65 && ch <= 8'd90) begin
        char_to_var = ch - 8'd65;
    end else begin
        char_to_var = 6'd63;  // Invalid
    end
endfunction

function automatic [5:0] char_to_term(input [7:0] ch);
    // Convert terminals: 'a'-'z' (0-25), space (26)
    if (ch >= 8'd97 && ch <= 8'd122) begin
        char_to_term = ch - 8'd97;
    end else if (ch == 8'd32) begin
        char_to_term = 6'd26;
    end else begin
        char_to_term = 6'd63;  // Invalid
    end
endfunction

// State transition logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        busy <= 1'b0;
        result_start <= 4'd0;
        result_len <= 4'd0;
        input_buffer_index <= 4'd0;
        rule_count <= 4'd0;
        rule_index <= 4'd0;
        row <= 4'd0;
        col <= 4'd0;
        mid <= 4'd0;
        span_len <= 4'd0;
        cycle_count <= 8'd0;
        best_start_temp <= 4'd0;
        best_len_temp <= 4'd0;
        scan_i <= 4'd0;
        scan_j <= 4'd0;
    end else begin
        // Clear done when new start
        if (start) begin
            done <= 1'b0;
        end
        
        case (state)
            IDLE: begin
                busy <= 1'b0;
                done <= 1'b0;
                result_start <= 4'd0;
                result_len <= 4'd0;
                input_buffer_index <= 4'd0;
                rule_count <= 4'd0;
                rule_index <= 4'd0;
                row <= 4'd0;
                col <= 4'd0;
                mid <= 4'd0;
                span_len <= 4'd0;
                cycle_count <= 8'd0;
                
                if (start && text_mode) begin
                    state <= LOAD_TEXT;
                    busy <= 1'b1;
                end else if (start && !text_mode) begin
                    state <= LOAD_RULES;
                    busy <= 1'b1;
                    rule_count <= 4'd0;
                end
            end
            
            LOAD_TEXT: begin
                // Store char_in into buffer
                if (input_buffer_index < input_len && input_buffer_index < 4'd16) begin
                    input_buffer[input_buffer_index] <= char_in;
                    input_buffer_index <= input_buffer_index + 4'd1;
                end
                
                // If we've loaded all chars or reached max
                if (input_buffer_index >= input_len || input_buffer_index >= 4'd15) begin
                    if (text_mode == 1'b0) begin
                        state <= LOAD_RULES;
                        rule_index <= 4'd0;
                    end else begin
                        // Need to wait for text_mode to go low or external trigger
                        // For now, assume immediate transition
                        state <= IDLE;
                        done <= 1'b1;
                        busy <= 1'b0;
                    end
                end
            end
            
            LOAD_RULES: begin
                // Store cfg_rules into rules array
                if (rule_index < 4'd16 && rule_index < input_len) begin
                    rules[rule_index] <= cfg_rules;
                    rule_index <= rule_index + 4'd1;
                end
                
                // If loaded enough rules or timeout
                if (rule_index >= input_len - 4'd1 || rule_index >= 4'd15) begin
                    rule_count <= rule_index + 4'd1;
                    state <= PARSE_INIT;
                end
            end
            
            PARSE_INIT: begin
                // Initialize parse table
                // Fill for span_len = 1 (single characters)
                // Input buffer index = col (0 to input_len-1)
                if (row < input_len) begin
                    parse_table[row][row] <= 26'd0;  // Clear
                    
                    // Check if char matches any rule producing single char
                    for (rule_index = 0; rule_index < rule_count; rule_index = rule_index + 1) begin
                        rule_head = rules[rule_index][31:24];
                        rule_body = rules[rule_index][23:0];
                        body_char0 = rule_body[23:16];
                        body_char1 = rule_body[15:8];
                        body_char2 = rule_body[7:0];
                        
                        // Check if rule produces this single character
                        if (body_char0 == input_buffer[row] && body_char1 == 8'hFF && body_char2 == 8'hFF) begin
                            parse_table[row][row] <= parse_table[row][row] | (26'd1 << char_to_var(rule_head));
                        end
                    end
                    
                    row <= row + 4'd1;
                end else begin
                    // Reset for main parsing loop
                    row <= 4'd0;
                    col <= 4'd1;  // Start from span_len=2
                    state <= PARSE_LOOP;
                    cycle_count <= 8'd0;
                end
            end
            
            PARSE_LOOP: begin
                // CYK-style parsing: fill table diagonally
                // i = row, j = col, span_len = col - row + 1
                // k = mid from row to j-1
                
                if (col < input_len) begin
                    if (mid < col) begin
                        // Check all rules for combining parse_table[row][mid] and parse_table[mid+1][col]
                        left_mask = parse_table[row][mid];
                        right_mask = parse_table[mid+1][col];
                        
                        // For each rule, check if body matches left and right
                        for (rule_index = 0; rule_index < rule_count; rule_index = rule_index + 1) begin
                            rule_head = rules[rule_index][31:24];
                            rule_body = rules[rule_index][23:0];
                            body_char0 = rule_body[23:16];
                            body_char1 = rule_body[15:8];
                            body_char2 = rule_body[7:0];
                            
                            // Check if rule produces 2 chars
                            if (body_char2 == 8'hFF) begin
                                // body_char0 and body_char1 are terminals or variables
                                // We need to check if left_mask contains body_char0 and right_mask contains body_char1
                                // But rule_body is character codes, not variable bits
                                // Simplified: check if rule matches variable combination
                                // This requires character-to-variable conversion for terminals
                                
                                // For terminals: check if they match input at that position
                                // For variables: check bit in mask
                                
                                // This is simplified - full implementation needs more logic
                                // Check if body_char0 is a terminal that matches
                                // and body_char1 is a terminal that matches
                                // OR check if they are variables in the masks
                                
                                // For this implementation, we'll check terminal matches directly
                                // and variable matches via bitmasks
                                
                                // Check left side
                                reg left_match;
                                left_match = 1'b0;
                                if (body_char0 >= 8'd65 && body_char0 <= 8'd90) begin
                                    // Variable - check bit in left_mask
                                    if (left_mask[char_to_var(body_char0)]) left_match = 1'b1;
                                end else begin
                                    // Terminal - check if it matches input at position row
                                    if (body_char0 == input_buffer[row]) left_match = 1'b1;
                                end
                                
                                // Check right side
                                reg right_match;
                                right_match = 1'b0;
                                if (body_char1 >= 8'd65 && body_char1 <= 8'd90) begin
                                    if (right_mask[char_to_var(body_char1)]) right_match = 1'b1;
                                end else begin
                                    if (body_char1 == input_buffer[mid+1]) right_match = 1'b1;
                                end
                                
                                if (left_match && right_match) begin
                                    parse_table[row][col] <= parse_table[row][col] | (26'd1 << char_to_var(rule_head));
                                end
                            end
                            // 3-char productions would require checking span_len >= 3
                            // For simplicity, we'll stick to 2-char productions for CYK
                            // (can be extended for 3-char with deeper loops)
                        end
                        
                        mid <= mid + 4'd1;
                    end else begin
                        // Reset mid for next col
                        mid <= row;
                        
                        // Move to next position
                        if (row < col - 4'd1) begin
                            row <= row + 4'd1;
                        end else begin
                            // Reset for next diagonal
                            row <= 4'd0;
                            col <= col + 4'd1;
                        end
                    end
                end else begin
                    // Parsing complete, find best match
                    state <= FIND_BEST;
                    best_start_temp <= 4'd0;
                    best_len_temp <= 4'd0;
                    scan_i <= 4'd0;
                    scan_j <= 4'd0;
                end
                
                // Cycle counter
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    state <= FIND_BEST;  // Timeout
                end
            end
            
            FIND_BEST: begin
                // Search parse_table for longest span containing start variable (A = bit 0)
                // Check from longest to shortest, earliest to latest
                
                // Simplified search: scan all spans, find longest with S
                if (scan_i < input_len) begin
                    if (scan_j < input_len) begin
                        if (scan_j >= scan_i) begin
                            // Check if S is in parse_table[scan_i][scan_j]
                            if (parse_table[scan_i][scan_j][0]) begin  // A is variable 0
                                // Found match
                                reg [3:0] span = scan_j - scan_i + 4'd1;
                                if (span > best_len_temp || (span == best_len_temp && scan_i < best_start_temp)) begin
                                    best_start_temp <= scan_i;
                                    best_len_temp <= span;
                                end
                            end
                            scan_j <= scan_j + 4'd1;
                        end else begin
                            scan_j <= scan_i;
                        end
                    end else begin
                        scan_j <= 4'd0;
                        scan_i <= scan_i + 4'd1;
                    end
                end else begin
                    // Done searching
                    result_start <= best_start_temp;
                    result_len <= best_len_temp;
                    state <= FINISH;
                end
            end
            
            FINISH: begin
                done <= 1'b1;
                busy <= 1'b0;
                state <= IDLE;
            end
            
            default: begin
                state <= IDLE;
                busy <= 1'b0;
                done <= 1'b0;
            end
        endcase
    end
end

endmodule