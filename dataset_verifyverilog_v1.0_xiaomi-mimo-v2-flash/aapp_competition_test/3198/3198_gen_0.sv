module TypoDetector (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] word_count,
    input wire [3:0] word_len [0:15],
    input wire [127:0] word_data [0:15],
    output reg [3:0] result_index,
    output reg is_typo,
    output reg done,
    output reg busy
);

    // State definitions
    localparam [3:0] IDLE           = 4'd0;
    localparam [3:0] SETUP          = 4'd1;
    localparam [3:0] CHECK_DELETIONS = 4'd2;
    localparam [3:0] VERIFY_EXISTENCE = 4'd3;
    localparam [3:0] OUTPUT         = 4'd4;
    localparam [3:0] NEXT_WORD      = 4'd5;
    localparam [3:0] FINISH         = 4'd6;

    // Internal registers
    reg [3:0] state, next_state;
    reg [3:0] current_word_idx;     // Index of word being checked
    reg [3:0] current_word_len;     // Length of current word
    reg [127:0] current_word_data;  // Packed word data
    reg [3:0] delete_pos;           // Position of character to delete
    reg [3:0] check_idx;            // Index of word being compared
    reg found_match;                // Flag indicating typo found
    reg [7:0] current_char;         // Current character being processed
    reg [7:0] candidate_char;       // Character from candidate word
    reg [7:0] compare_char;         // Character from comparison word
    reg [3:0] comp_pos;             // Position in comparison word
    reg [3:0] candidate_pos;        // Position in candidate word
    reg [7:0] cycle_count;          // Safety cycle counter
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Temp storage for candidate word (after deletion)
    reg [7:0] candidate_chars [0:15];
    reg [3:0] candidate_len;

    integer i; // Loop variable

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_index <= 4'd0;
            is_typo <= 1'b0;
            done <= 1'b0;
            busy <= 1'b0;
            current_word_idx <= 4'd0;
            current_word_len <= 4'd0;
            current_word_data <= 128'd0;
            delete_pos <= 4'd0;
            check_idx <= 4'd0;
            found_match <= 1'b0;
            current_char <= 8'd0;
            candidate_char <= 8'd0;
            compare_char <= 8'd0;
            comp_pos <= 4'd0;
            candidate_pos <= 4'd0;
            cycle_count <= 8'd0;
            candidate_len <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                candidate_chars[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    current_word_idx <= 4'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        busy <= 1'b1;
                    end
                end

                SETUP: begin
                    // Load current word data and length
                    current_word_data <= word_data[current_word_idx];
                    current_word_len <= word_len[current_word_idx];
                    delete_pos <= 4'd0;
                    found_match <= 1'b0;
                end

                CHECK_DELETIONS: begin
                    // Build candidate word by deleting character at delete_pos
                    // Extract characters from current_word_data
                    // current_word_data[7:0] is char 0, [15:8] is char 1, etc.
                    if (delete_pos < current_word_len) begin
                        candidate_len <= current_word_len - 4'd1;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < delete_pos) begin
                                // Copy before deletion point
                                candidate_chars[i] <= current_word_data[(i * 8) +: 8];
                            end else if (i < current_word_len - 4'd1) begin
                                // Shift after deletion point
                                candidate_chars[i] <= current_word_data[((i + 1) * 8) +: 8];
                            end else begin
                                // Clear remaining
                                candidate_chars[i] <= 8'd0;
                            end
                        end
                    end
                end

                VERIFY_EXISTENCE: begin
                    // Compare candidate word against all other dictionary words
                    // Reset compare indices for new comparison
                    if (check_idx == 4'd0 && comp_pos == 4'd0) begin
                        comp_pos <= 4'd0;
                        candidate_pos <= 4'd0;
                    end
                end

                OUTPUT: begin
                    result_index <= current_word_idx;
                    is_typo <= found_match;
                    done <= 1'b1;  // Pulse done
                    busy <= 1'b0;  // Clear busy for this word
                end

                NEXT_WORD: begin
                    current_word_idx <= current_word_idx + 4'd1;
                    done <= 1'b0;
                    busy <= 1'b1;
                    cycle_count <= cycle_count + 8'd1;
                end

                FINISH: begin
                    done <= 1'b1;
                    busy <= 1'b0;
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
                    next_state = SETUP;
                end else begin
                    next_state = IDLE;
                end
            end

            SETUP: begin
                // If word length is 0 or 1, skip deletion checks (no valid deletion)
                if (current_word_len < 4'd2) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = CHECK_DELETIONS;
                end
            end

            CHECK_DELETIONS: begin
                if (delete_pos < current_word_len) begin
                    // Start verification for this deletion
                    check_idx <= 4'd0;
                    comp_pos <= 4'd0;
                    next_state = VERIFY_EXISTENCE;
                end else begin
                    // No more deletion positions to check
                    if (found_match) begin
                        next_state = OUTPUT;
                    end else begin
                        next_state = OUTPUT; // is_typo remains 0
                    end
                end
            end

            VERIFY_EXISTENCE: begin
                // Check if candidate matches word at check_idx
                // Skip if check_idx == current_word_idx (same word)
                if (check_idx == current_word_len) begin
                    check_idx <= 4'd0;
                    comp_pos <= 4'd0;
                    candidate_pos <= 4'd0;
                    next_state = CHECK_DELETIONS;
                    delete_pos <= delete_pos + 4'd1;
                end else if (check_idx == current_word_idx) begin
                    // Skip this index
                    check_idx <= check_idx + 4'd1;
                    next_state = VERIFY_EXISTENCE;
                end else begin
                    // Compare characters
                    if (comp_pos < word_len[check_idx]) begin
                        // Get comparison character
                        compare_char = word_data[check_idx][(comp_pos * 8) +: 8];
                        // Get candidate character
                        candidate_char = (candidate_pos < candidate_len) ? candidate_chars[candidate_pos] : 8'd0;
                        
                        if (candidate_pos >= candidate_len && comp_pos < word_len[check_idx]) begin
                            // Candidate finished but comparison word has more chars
                            if (check_idx + 4'd1 >= word_count) begin
                                // No match found, check next deletion
                                check_idx <= 4'd0;
                                comp_pos <= 4'd0;
                                candidate_pos <= 4'd0;
                                next_state = CHECK_DELETIONS;
                                delete_pos <= delete_pos + 4'd1;
                            end else begin
                                check_idx <= check_idx + 4'd1;
                                comp_pos <= 4'd0;
                                candidate_pos <= 4'd0;
                                next_state = VERIFY_EXISTENCE;
                            end
                        end else if (candidate_pos < candidate_len && comp_pos >= word_len[check_idx]) begin
                            // Candidate still has chars but comparison word finished
                            // No match
                            if (check_idx + 4'd1 >= word_count) begin
                                check_idx <= 4'd0;
                                comp_pos <= 4'd0;
                                candidate_pos <= 4'd0;
                                next_state = CHECK_DELETIONS;
                                delete_pos <= delete_pos + 4'd1;
                            end else begin
                                check_idx <= check_idx + 4'd1;
                                comp_pos <= 4'd0;
                                candidate_pos <= 4'd0;
                                next_state = VERIFY_EXISTENCE;
                            end
                        end else if (compare_char == candidate_char) begin
                            // Characters match, move to next
                            comp_pos <= comp_pos + 4'd1;
                            candidate_pos <= candidate_pos + 4'd1;
                            next_state = VERIFY_EXISTENCE;
                            // Check if we reached end of both
                            if (comp_pos + 4'd1 == word_len[check_idx] && candidate_pos + 4'd1 == candidate_len) begin
                                // Full match found!
                                found_match <= 1'b1;
                                // Skip to next deletion position
                                check_idx <= 4'd0;
                                comp_pos <= 4'd0;
                                candidate_pos <= 4'd0;
                                next_state = CHECK_DELETIONS;
                                delete_pos <= delete_pos + 4'd1;
                            end
                        end else begin
                            // Characters don't match, try next word
                            if (check_idx + 4'd1 >= word_count) begin
                                // No match found for this deletion
                                check_idx <= 4'd0;
                                comp_pos <= 4'd0;
                                candidate_pos <= 4'd0;
                                next_state = CHECK_DELETIONS;
                                delete_pos <= delete_pos + 4'd1;
                            end else begin
                                check_idx <= check_idx + 4'd1;
                                comp_pos <= 4'd0;
                                candidate_pos <= 4'd0;
                                next_state = VERIFY_EXISTENCE;
                            end
                        end
                    end else begin
                        // End of comparison word reached
                        if (candidate_pos == candidate_len) begin
                            // Match found!
                            found_match <= 1'b1;
                            // Skip to next deletion position
                            check_idx <= 4'd0;
                            comp_pos <= 4'd0;
                            candidate_pos <= 4'd0;
                            next_state = CHECK_DELETIONS;
                            delete_pos <= delete_pos + 4'd1;
                        end else begin
                            // No match, try next word
                            if (check_idx + 4'd1 >= word_count) begin
                                check_idx <= 4'd0;
                                comp_pos <= 4'd0;
                                candidate_pos <= 4'd0;
                                next_state = CHECK_DELETIONS;
                                delete_pos <= delete_pos + 4'd1;
                            end else begin
                                check_idx <= check_idx + 4'd1;
                                comp_pos <= 4'd0;
                                candidate_pos <= 4'd0;
                                next_state = VERIFY_EXISTENCE;
                            end
                        end
                    end
                end
            end

            OUTPUT: begin
                if (current_word_idx + 4'd1 >= word_count) begin
                    // Last word done
                    next_state = FINISH;
                end else begin
                    next_state = NEXT_WORD;
                end
            end

            NEXT_WORD: begin
                next_state = SETUP;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase

        // Safety: timeout
        if (cycle_count >= MAX_CYCLES) begin
            next_state = FINISH;
        end
    end

endmodule