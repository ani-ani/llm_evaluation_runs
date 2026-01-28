module StartWithP (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] words_in [0:7],
    output reg [127:0] word1_out,
    output reg [127:0] word2_out,
    output reg valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SCAN_CHAR = 3'd1;
    localparam [2:0] PARSE_WORD = 3'd2;
    localparam [2:0] CHECK_P = 3'd3;
    localparam [2:0] FOUND = 3'd4;
    localparam [2:0] DONE = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [2:0] string_idx;
    reg [3:0] char_idx;
    reg [3:0] word_idx;
    reg [127:0] current_string;
    reg [7:0] current_char;
    reg [127:0] first_word;
    reg [127:0] second_word;
    reg found_p_word;
    reg waiting_for_second;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd1024;

    // Output word construction
    reg [127:0] temp_word1;
    reg [127:0] temp_word2;
    reg [3:0] temp_idx;

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = SCAN_CHAR;
            end

            SCAN_CHAR: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = DONE;
                end else if (string_idx < 8) begin
                    next_state = PARSE_WORD;
                end else begin
                    next_state = DONE;
                end
            end

            PARSE_WORD: begin
                if (char_idx < 16) begin
                    if (current_char == 8'h20) begin // Space
                        // End of word - check if we were looking for P
                        if (waiting_for_second && found_p_word) begin
                            next_state = FOUND;
                        end else begin
                            // Continue to next word
                            next_state = CHECK_P;
                        end
                    end else if (char_idx == 0) begin
                        // Start of word, check first char
                        next_state = CHECK_P;
                    end else begin
                        // Continue current word
                        next_state = PARSE_WORD;
                    end
                end else begin
                    // End of string
                    if (waiting_for_second && found_p_word) begin
                        next_state = FOUND;
                    end else begin
                        next_state = SCAN_CHAR;
                    end
                end
            end

            CHECK_P: begin
                // Check if current char is 'P' (0x50)
                if (current_char == 8'h50) begin
                    if (!found_p_word) begin
                        // Found first P-word
                        next_state = PARSE_WORD;
                    end else if (waiting_for_second) begin
                        // Found second P-word
                        next_state = PARSE_WORD;
                    end else begin
                        next_state = PARSE_WORD;
                    end
                end else begin
                    // Not a P-word, continue parsing
                    next_state = PARSE_WORD;
                end
            end

            FOUND: begin
                next_state = DONE;
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // State register and outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            string_idx <= 3'd0;
            char_idx <= 4'd0;
            word_idx <= 4'd0;
            current_string <= 128'd0;
            current_char <= 8'd0;
            first_word <= 128'd0;
            second_word <= 128'd0;
            found_p_word <= 1'b0;
            waiting_for_second <= 1'b0;
            temp_word1 <= 128'd0;
            temp_word2 <= 128'd0;
            temp_idx <= 4'd0;
            cycle_count <= 16'd0;
            word1_out <= 128'd0;
            word2_out <= 128'd0;
            valid <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            done <= 1'b0;
            valid <= 1'b0;
            cycle_count <= cycle_count + 16'd1;

            case (state)
                IDLE: begin
                    if (start) begin
                        string_idx <= 3'd0;
                        char_idx <= 4'd0;
                        word_idx <= 4'd0;
                        current_string <= words_in[0];
                        found_p_word <= 1'b0;
                        waiting_for_second <= 1'b0;
                        first_word <= 128'd0;
                        second_word <= 128'd0;
                        temp_word1 <= 128'd0;
                        temp_word2 <= 128'd0;
                        temp_idx <= 4'd0;
                        cycle_count <= 16'd0;
                    end
                end

                SCAN_CHAR: begin
                    if (string_idx < 8'd8) begin
                        current_string <= words_in[string_idx];
                        char_idx <= 4'd0;
                        word_idx <= 4'd0;
                    end
                end

                PARSE_WORD: begin
                    // Extract current character
                    case (char_idx)
                        4'd0: current_char <= current_string[7:0];
                        4'd1: current_char <= current_string[15:8];
                        4'd2: current_char <= current_string[23:16];
                        4'd3: current_char <= current_string[31:24];
                        4'd4: current_char <= current_string[39:32];
                        4'd5: current_char <= current_string[47:40];
                        4'd6: current_char <= current_string[55:48];
                        4'd7: current_char <= current_string[63:56];
                        4'd8: current_char <= current_string[71:64];
                        4'd9: current_char <= current_string[79:72];
                        4'd10: current_char <= current_string[87:80];
                        4'd11: current_char <= current_string[95:88];
                        4'd12: current_char <= current_string[103:96];
                        4'd13: current_char <= current_string[111:104];
                        4'd14: current_char <= current_string[119:112];
                        4'd15: current_char <= current_string[127:120];
                        default: current_char <= 8'd0;
                    endcase

                    // Handle word building
                    if (char_idx < 16) begin
                        if (current_char == 8'h20 || char_idx == 4'd15) begin
                            // Word ended
                            if (waiting_for_second && found_p_word) begin
                                // Word built in FOUND state
                            end else if (found_p_word) begin
                                // Second word just completed
                                second_word <= temp_word2;
                                waiting_for_second <= 1'b1;
                            end
                            // Reset temp for next word
                            temp_idx <= 4'd0;
                            temp_word2 <= 128'd0;
                            temp_word1 <= temp_word1; // Keep first word
                        end else begin
                            // Character belongs to word
                            if (waiting_for_second) begin
                                // Building second word
                                case (temp_idx)
                                    4'd0: temp_word2[7:0] <= current_char;
                                    4'd1: temp_word2[15:8] <= current_char;
                                    4'd2: temp_word2[23:16] <= current_char;
                                    4'd3: temp_word2[31:24] <= current_char;
                                    4'd4: temp_word2[39:32] <= current_char;
                                    4'd5: temp_word2[47:40] <= current_char;
                                    4'd6: temp_word2[55:48] <= current_char;
                                    4'd7: temp_word2[63:56] <= current_char;
                                    4'd8: temp_word2[71:64] <= current_char;
                                    4'd9: temp_word2[79:72] <= current_char;
                                    4'd10: temp_word2[87:80] <= current_char;
                                    4'd11: temp_word2[95:88] <= current_char;
                                    4'd12: temp_word2[103:96] <= current_char;
                                    4'd13: temp_word2[111:104] <= current_char;
                                    4'd14: temp_word2[119:112] <= current_char;
                                    4'd15: temp_word2[127:120] <= current_char;
                                endcase
                            end else if (found_p_word) begin
                                // Building second word (not yet waiting)
                                case (temp_idx)
                                    4'd0: temp_word2[7:0] <= current_char;
                                    4'd1: temp_word2[15:8] <= current_char;
                                    4'd2: temp_word2[23:16] <= current_char;
                                    4'd3: temp_word2[31:24] <= current_char;
                                    4'd4: temp_word2[39:32] <= current_char;
                                    4'd5: temp_word2[47:40] <= current_char;
                                    4'd6: temp_word2[55:48] <= current_char;
                                    4'd7: temp_word2[63:56] <= current_char;
                                    4'd8: temp_word2[71:64] <= current_char;
                                    4'd9: temp_word2[79:72] <= current_char;
                                    4'd10: temp_word2[87:80] <= current_char;
                                    4'd11: temp_word2[95:88] <= current_char;
                                    4'd12: temp_word2[103:96] <= current_char;
                                    4'd13: temp_word2[111:104] <= current_char;
                                    4'd14: temp_word2[119:112] <= current_char;
                                    4'd15: temp_word2[127:120] <= current_char;
                                endcase
                            end else begin
                                // Building first word
                                case (temp_idx)
                                    4'd0: temp_word1[7:0] <= current_char;
                                    4'd1: temp_word1[15:8] <= current_char;
                                    4'd2: temp_word1[23:16] <= current_char;
                                    4'd3: temp_word1[31:24] <= current_char;
                                    4'd4: temp_word1[39:32] <= current_char;
                                    4'd5: temp_word1[47:40] <= current_char;
                                    4'd6: temp_word1[55:48] <= current_char;
                                    4'd7: temp_word1[63:56] <= current_char;
                                    4'd8: temp_word1[71:64] <= current_char;
                                    4'd9: temp_word1[79:72] <= current_char;
                                    4'd10: temp_word1[87:80] <= current_char;
                                    4'd11: temp_word1[95:88] <= current_char;
                                    4'd12: temp_word1[103:96] <= current_char;
                                    4'd13: temp_word1[111:104] <= current_char;
                                    4'd14: temp_word1[119:112] <= current_char;
                                    4'd15: temp_word1[127:120] <= current_char;
                                endcase
                            end
                            temp_idx <= temp_idx + 4'd1;
                        end
                        char_idx <= char_idx + 4'd1;
                    end else begin
                        // End of string
                        char_idx <= 4'd0;
                        string_idx <= string_idx + 3'd1;
                    end
                end

                CHECK_P: begin
                    // Check first character of word
                    if (current_char == 8'h50) begin
                        if (!found_p_word) begin
                            // First P-word found
                            first_word <= temp_word1;
                            found_p_word <= 1'b1;
                            temp_word1 <= 128'd0; // Start building second word
                            temp_idx <= 4'd0;
                        end else if (waiting_for_second) begin
                            // Second P-word found
                            second_word <= temp_word2;
                            found_p_word <= 1'b1;
                            waiting_for_second <= 1'b0;
                            temp_idx <= 4'd0;
                        end else begin
                            // Second P-word found (consecutive)
                            second_word <= temp_word2;
                            found_p_word <= 1'b1;
                            waiting_for_second <= 1'b0;
                            temp_idx <= 4'd0;
                        end
                    end
                end

                FOUND: begin
                    word1_out <= first_word;
                    word2_out <= second_word;
                    valid <= 1'b1;
                    done <= 1'b1;
                end

                DONE: begin
                    done <= 1'b1;
                    if (!found_p_word) begin
                        valid <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule