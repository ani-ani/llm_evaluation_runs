module word_processor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [511:0] input_string,
    input wire [3:0] n,
    input wire [5:0] len,
    output reg result_found,
    output reg [127:0] result_word,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] PARSE_CHAR  = 3'd1;
    localparam [2:0] CHECK_SPACE = 3'd2;
    localparam [3:0] COUNT_CONS  = 3'd3;
    localparam [2:0] CHECK_MATCH = 3'd4;
    localparam [2:0] OUTPUT_WORD = 3'd5;
    localparam [2:0] FINISH      = 3'd6;

    // Registers
    reg [2:0] state, next_state;
    reg [5:0] char_idx;          // Current character index (0-63)
    reg [5:0] word_start_idx;    // Start of current word
    reg [5:0] word_len;          // Length of current word (0-16)
    reg [7:0] temp_word [0:15];  // Buffer for current word (16 bytes)
    reg [3:0] cons_count;        // Consonant count for current word
    reg [3:0] vowel_match;       // Flag for vowel detection
    reg found_flag;              // Found matching word
    reg [127:0] found_word_reg;  // Registered result word
    reg [7:0] current_char;      // Current ASCII character
    reg [7:0] current_byte;      // Byte from input string
    reg [3:0] i;                 // Loop variable for vowel check
    reg [3:0] j;                 // Loop variable for word copy
    reg [3:0] k;                 // Loop variable for bit extraction

    // Vowel table (aeiouAEIOU)
    // We'll check each character against these
    always @(*) begin
        vowel_match = 4'd0;
        case (current_char)
            8'h41, 8'h45, 8'h49, 8'h4F, 8'h55, 8'h61, 8'h65, 8'h69, 8'h6F, 8'h75: begin
                vowel_match = 4'd1; // Vowel
            end
            default: begin
                vowel_match = 4'd0; // Not vowel (or y/Y treated as consonant)
            end
        endcase
    end

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_idx <= 6'd0;
            word_start_idx <= 6'd0;
            word_len <= 6'd0;
            cons_count <= 4'd0;
            found_flag <= 1'b0;
            found_word_reg <= 128'd0;
            result_found <= 1'b0;
            result_word <= 128'd0;
            done <= 1'b0;
            current_char <= 8'd0;
            current_byte <= 8'd0;
            for (k = 0; k < 16; k = k + 1) begin
                temp_word[k] <= 8'd0;
            end
        end else begin
            // Default outputs
            result_found <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        char_idx <= 6'd0;
                        word_start_idx <= 6'd0;
                        word_len <= 6'd0;
                        cons_count <= 4'd0;
                        found_flag <= 1'b0;
                        state <= PARSE_CHAR;
                    end
                end

                PARSE_CHAR: begin
                    // Extract current character from input_string
                    // input_string[511:0], each char is 8 bits
                    // Char 0 is input_string[511:504], Char 63 is input_string[7:0]
                    current_byte <= input_string[(511 - (char_idx * 8)) -: 8];
                    current_char <= input_string[(511 - (char_idx * 8)) -: 8];
                    state <= CHECK_SPACE;
                end

                CHECK_SPACE: begin
                    // Check if space (0x20) or end of string
                    if (current_char == 8'h20 || char_idx >= len) begin
                        // End of word or string
                        if (word_len > 0) begin
                            // Process the word that just ended
                            cons_count <= 4'd0;
                            j <= 6'd0; // Initialize loop for vowel check
                            state <= COUNT_CONS;
                        end else begin
                            // No word, check if done
                            if (char_idx >= len) begin
                                state <= FINISH;
                            end else begin
                                // Skip space, move to next char
                                char_idx <= char_idx + 6'd1;
                                word_start_idx <= char_idx + 6'd1;
                                state <= PARSE_CHAR;
                            end
                        end
                    end else begin
                        // Accumulate character into temp_word
                        if (word_len < 16) begin
                            temp_word[word_len] <= current_char;
                            word_len <= word_len + 6'd1;
                        end
                        // Move to next character
                        char_idx <= char_idx + 6'd1;
                        state <= PARSE_CHAR;
                    end
                end

                COUNT_CONS: begin
                    // Check if current char is consonant
                    if (vowel_match == 4'd1) begin
                        // Vowel - do nothing to cons_count
                        cons_count <= cons_count;
                    end else begin
                        // Consonant (including y/Y)
                        if (current_char >= 8'h41 && current_char <= 8'h7A) begin
                            cons_count <= cons_count + 4'd1;
                        end
                        // Non-letters are ignored in consonant count
                    end
                    
                    j <= j + 4'd1;
                    if (j < word_len) begin
                        // Get next character from temp_word for checking
                        current_char <= temp_word[j];
                        state <= COUNT_CONS;
                    end else begin
                        state <= CHECK_MATCH;
                    end
                end

                CHECK_MATCH: begin
                    // Check if consonant count matches n
                    if (cons_count == n) begin
                        found_flag <= 1'b1;
                        // Copy temp_word to found_word_reg (128-bit)
                        // We need to copy byte by byte
                        // Start copying
                        for (k = 0; k < 16; k = k + 1) begin
                            if (k < word_len) begin
                                found_word_reg[(127 - (k*8)) -: 8] <= temp_word[k];
                            end else begin
                                found_word_reg[(127 - (k*8)) -: 8] <= 8'd0;
                            end
                        end
                    end else begin
                        found_flag <= 1'b0;
                    end
                    
                    // Move to next word
                    word_len <= 6'd0;
                    
                    // Check if we are at end of string
                    if (char_idx >= len) begin
                        state <= FINISH;
                    end else begin
                        // Reset temp_word
                        for (k = 0; k < 16; k = k + 1) begin
                            temp_word[k] <= 8'd0;
                        end
                        word_start_idx <= char_idx;
                        state <= PARSE_CHAR;
                    end
                end

                OUTPUT_WORD: begin
                    // Output the found word
                    result_found <= 1'b1;
                    result_word <= found_word_reg;
                    
                    // Continue processing
                    found_flag <= 1'b0;
                    
                    // Check if we are at end of string
                    if (char_idx >= len) begin
                        state <= FINISH;
                    end else begin
                        state <= PARSE_CHAR;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Special handling: If found_flag is set, go to OUTPUT_WORD
            // This needs to be handled carefully with state transitions
            // Let's modify the logic to handle output in CHECK_MATCH
            if (state == CHECK_MATCH && found_flag) begin
                state <= OUTPUT_WORD;
            end
        end
    end

    // State transition helper (to avoid combinational loop in single always block)
    always @(*) begin
        next_state = state;
        case (state)
            CHECK_MATCH: begin
                if (found_flag) begin
                    next_state = OUTPUT_WORD;
                end else if (char_idx >= len) begin
                    next_state = FINISH;
                end else begin
                    next_state = PARSE_CHAR;
                end
            end
            default: next_state = state;
        endcase
    end

    // Update state in always block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            if (state != CHECK_MATCH) begin
                // Only update if not in CHECK_MATCH to avoid conflict
                // Actually, we should always update next_state logic
            end
            // Integrated above
        end
    end
    
    // Rewrite to fix combinational logic and state updates
    // Clear the previous always blocks and rewrite properly
endmodule

// CORRECTED VERSION
module word_processor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [511:0] input_string,
    input wire [3:0] n,
    input wire [5:0] len,
    output reg result_found,
    output reg [127:0] result_word,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] PARSE_CHAR  = 3'd1;
    localparam [2:0] CHECK_SPACE = 3'd2;
    localparam [2:0] COUNT_CONS  = 3'd3;
    localparam [2:0] CHECK_MATCH = 3'd4;
    localparam [2:0] OUTPUT_WORD = 3'd5;
    localparam [2:0] FINISH      = 3'd6;

    // Registers
    reg [2:0] state;
    reg [5:0] char_idx;
    reg [5:0] word_len;
    reg [7:0] temp_word [0:15];
    reg [3:0] cons_count;
    reg found_flag;
    reg [127:0] found_word_reg;
    reg [7:0] current_char;
    reg [3:0] j;
    reg [3:0] k;

    // Vowel check logic
    always @(*) begin
        case (current_char)
            8'h41, 8'h45, 8'h49, 8'h4F, 8'h55, 8'h61, 8'h65, 8'h69, 8'h6F, 8'h75: begin
                vowel_match = 1'b1;
            end
            default: vowel_match = 1'b0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_idx <= 6'd0;
            word_len <= 6'd0;
            cons_count <= 4'd0;
            found_flag <= 1'b0;
            found_word_reg <= 128'd0;
            result_found <= 1'b0;
            result_word <= 128'd0;
            done <= 1'b0;
            current_char <= 8'd0;
            for (k = 0; k < 16; k = k + 1) temp_word[k] <= 8'd0;
        end else begin
            // Default de-assert
            result_found <= 1'b0;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        char_idx <= 6'd0;
                        word_len <= 6'd0;
                        cons_count <= 4'd0;
                        found_flag <= 1'b0;
                        state <= PARSE_CHAR;
                    end
                end

                PARSE_CHAR: begin
                    current_char <= input_string[(511 - (char_idx * 8)) -: 8];
                    state <= CHECK_SPACE;
                end

                CHECK_SPACE: begin
                    if (current_char == 8'h20 || char_idx >= len) begin
                        if (word_len > 0) begin
                            // Process word
                            j <= 6'd0;
                            cons_count <= 4'd0;
                            state <= COUNT_CONS;
                        end else begin
                            // Skip space
                            if (char_idx >= len) begin
                                state <= FINISH;
                            end else begin
                                char_idx <= char_idx + 6'd1;
                                state <= PARSE_CHAR;
                            end
                        end
                    end else begin
                        // Accumulate
                        if (word_len < 16) begin
                            temp_word[word_len] <= current_char;
                            word_len <= word_len + 6'd1;
                        end
                        char_idx <= char_idx + 6'd1;
                        state <= PARSE_CHAR;
                    end
                end

                COUNT_CONS: begin
                    // Check char at j
                    if (vowel_match == 1'b0 && (current_char >= 8'h41 && current_char <= 8'h7A)) begin
                        cons_count <= cons_count + 4'd1;
                    end
                    
                    j <= j + 4'd1;
                    if (j < word_len - 1) begin
                        current_char <= temp_word[j + 1];
                        state <= COUNT_CONS;
                    end else begin
                        state <= CHECK_MATCH;
                    end
                end

                CHECK_MATCH: begin
                    if (cons_count == n) begin
                        found_flag <= 1'b1;
                        // Pack temp_word into found_word_reg
                        found_word_reg <= {temp_word[0], temp_word[1], temp_word[2], temp_word[3],
                                           temp_word[4], temp_word[5], temp_word[6], temp_word[7],
                                           temp_word[8], temp_word[9], temp_word[10], temp_word[11],
                                           temp_word[12], temp_word[13], temp_word[14], temp_word[15]};
                        state <= OUTPUT_WORD;
                    end else begin
                        found_flag <= 1'b0;
                        word_len <= 6'd0;
                        if (char_idx >= len) begin
                            state <= FINISH;
                        end else begin
                            state <= PARSE_CHAR;
                        end
                    end
                end

                OUTPUT_WORD: begin
                    result_found <= 1'b1;
                    result_word <= found_word_reg;
                    found_flag <= 1'b0;
                    word_len <= 6'd0;
                    if (char_idx >= len) begin
                        state <= FINISH;
                    end else begin
                        state <= PARSE_CHAR;
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