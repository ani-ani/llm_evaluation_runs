module find_max_word(
    input clk,
    input rst_n,
    input start,
    input [3:0] num_words,
    input [63:0] words_data [0:15],
    output reg [63:0] result,
    output reg done,
    output reg [2:0] status
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] PROC_WORD = 3'd1;  // Process individual word
    localparam [2:0] CHECK_DUP = 3'd2;  // Check character uniqueness
    localparam [2:0] COMPARE   = 3'd3;  // Compare with best
    localparam [2:0] FINISH    = 3'd4;
    localparam [2:0] ERROR     = 3'd5;

    // Status codes
    localparam [2:0] STATUS_IDLE      = 3'd0;
    localparam [2:0] STATUS_PROCESSING = 3'd1;
    localparam [2:0] STATUS_DONE      = 3'd2;
    localparam [2:0] STATUS_ERROR     = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] word_idx;           // Current word index (0 to num_words-1)
    reg [3:0] char_idx;           // Current character index (0 to 7)
    reg [7:0] char_present;       // 8-bit array for unique chars (a-z)
    reg [3:0] current_unique_cnt; // Unique count for current word
    reg [3:0] best_unique_cnt;    // Best unique count found so far
    reg [63:0] best_word;         // Best word found so far
    reg [3:0] cycle_count;        // Cycle counter (0-15)
    reg [7:0] temp_char;          // Temporary storage for current char
    reg [7:0] other_char;         // For comparison
    reg cmp_result;               // Comparison result
    reg [2:0] loop_counter;       // For lexicographical comparison loop

    // Combinational logic for status output
    always @(*) begin
        case (state)
            IDLE: status = STATUS_IDLE;
            PROC_WORD, CHECK_DUP, COMPARE: status = STATUS_PROCESSING;
            FINISH: status = STATUS_DONE;
            ERROR: status = STATUS_ERROR;
            default: status = STATUS_ERROR;
        endcase
    end

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 64'd0;
            done <= 1'b0;
            word_idx <= 4'd0;
            char_idx <= 4'd0;
            char_present <= 8'd0;
            current_unique_cnt <= 4'd0;
            best_unique_cnt <= 4'd0;
            best_word <= 64'd0;
            cycle_count <= 4'd0;
            temp_char <= 8'd0;
            other_char <= 8'd0;
            cmp_result <= 1'b0;
            loop_counter <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    word_idx <= 4'd0;
                    char_idx <= 4'd0;
                    char_present <= 8'd0;
                    current_unique_cnt <= 4'd0;
                    best_unique_cnt <= 4'd0;
                    best_word <= 64'd0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        if (num_words == 4'd0 || num_words > 4'd16) begin
                            state <= ERROR;
                        end else begin
                            state <= PROC_WORD;
                        end
                    end
                end

                PROC_WORD: begin
                    // Initialize for processing new word
                    char_idx <= 4'd0;
                    char_present <= 8'd0;
                    current_unique_cnt <= 4'd0;
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Check for timeout
                    if (cycle_count >= 4'd15) begin
                        state <= ERROR;
                    end else begin
                        state <= CHECK_DUP;
                    end
                end

                CHECK_DUP: begin
                    // Process character at index char_idx
                    // Extract character from 64-bit word
                    // words_data[word_idx] is 8 chars, each 8 bits
                    temp_char <= words_data[word_idx][((8'd7 - char_idx) * 8) +: 8];
                    
                    // Check if character is alphabetic
                    // 'A'-'Z': 0x41-0x5A, 'a'-'z': 0x61-0x7A
                    if ((temp_char >= 8'd65 && temp_char <= 8'd90) || 
                        (temp_char >= 8'd97 && temp_char <= 8'd122)) begin
                        // Convert to lowercase if uppercase
                        if (temp_char >= 8'd65 && temp_char <= 8'd90) begin
                            temp_char <= temp_char + 8'd32; // Convert to lowercase
                        end
                        // Set bit in char_present
                        char_present[temp_char[4:0]] <= 1'b1;
                    end
                    
                    // Move to next character
                    if (char_idx < 4'd7) begin
                        char_idx <= char_idx + 4'd1;
                        state <= CHECK_DUP;
                    end else begin
                        // Count unique characters
                        current_unique_cnt <= 4'd0;
                        loop_counter <= 3'd0;
                        state <= COMPARE;
                    end
                end

                COMPARE: begin
                    // Count bits in char_present
                    if (loop_counter < 3'd8) begin
                        if (char_present[loop_counter]) begin
                            current_unique_cnt <= current_unique_cnt + 4'd1;
                        end
                        loop_counter <= loop_counter + 3'd1;
                    end else begin
                        // Counting done, compare with best
                        if (current_unique_cnt > best_unique_cnt) begin
                            // New best found
                            best_unique_cnt <= current_unique_cnt;
                            best_word <= words_data[word_idx];
                        end else if (current_unique_cnt == best_unique_cnt) begin
                            // Lexicographical comparison
                            // Compare from index 0 to 7
                            if (loop_counter < 3'd11) begin
                                // Determine which chars to compare
                                if (loop_counter < 3'd8) begin
                                    // Extract chars for comparison
                                    temp_char <= words_data[word_idx][((8'd7 - loop_counter) * 8) +: 8];
                                    other_char <= best_word[((8'd7 - loop_counter) * 8) +: 8];
                                    
                                    if (temp_char < other_char) begin
                                        // Current word is smaller
                                        best_word <= words_data[word_idx];
                                        loop_counter <= 3'd15; // Exit comparison
                                    end else if (temp_char > other_char) begin
                                        // Current word is larger, keep best
                                        loop_counter <= 3'd15; // Exit comparison
                                    end else begin
                                        // Equal, continue to next char
                                        loop_counter <= loop_counter + 3'd1;
                                    end
                                end else begin
                                    // All chars equal, current word is same or larger
                                    loop_counter <= 3'd15;
                                end
                            end else begin
                                // Comparison complete
                            end
                        end
                        
                        // Move to next word
                        if (word_idx < num_words - 4'd1) begin
                            word_idx <= word_idx + 4'd1;
                            state <= PROC_WORD;
                        end else begin
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    result <= best_word;
                    done <= 1'b1;
                    state <= IDLE;
                end

                ERROR: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule