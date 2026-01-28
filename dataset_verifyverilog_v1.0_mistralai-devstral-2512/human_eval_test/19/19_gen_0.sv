module number_word_sorter(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    output reg [39:0] sorted_words [0:7],
    output reg [2:0] word_count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] READ_WORDS = 3'd1;
    localparam [2:0] MAP_VALUES = 3'd2;
    localparam [2:0] SORT_VALUES = 3'd3;
    localparam [2:0] MAP_BACK   = 3'd4;
    localparam [2:0] OUTPUT     = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Word buffer (8 words, 5 chars each)
    reg [7:0] word_buffer [0:7][0:4];
    reg [3:0] word_values [0:7];
    reg [3:0] word_index;
    reg [2:0] char_index;
    reg [3:0] valid_word_count;

    // Character processing
    reg [7:0] current_char;
    reg char_ready;

    // Sorting variables
    reg [3:0] temp_values [0:7];
    reg [3:0] sort_i, sort_j;
    reg sort_done;

    // Word mapping
    reg [7:0] zero [0:4] = "zero";
    reg [7:0] one [0:4] = "one";
    reg [7:0] two [0:4] = "two";
    reg [7:0] three [0:4] = "three";
    reg [7:0] four [0:4] = "four";
    reg [7:0] five [0:4] = "five";
    reg [7:0] six [0:4] = "six";
    reg [7:0] seven [0:4] = "seven";
    reg [7:0] eight [0:4] = "eight";
    reg [7:0] nine [0:4] = "nine";

    // Initialize all registers
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            word_count <= 3'd0;
            word_index <= 4'd0;
            char_index <= 3'd0;
            valid_word_count <= 4'd0;
            char_ready <= 1'b0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            sort_done <= 1'b0;

            // Initialize word buffer
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 5; j = j + 1) begin
                    word_buffer[i][j] <= 8'd0;
                end
            end

            // Initialize word values
            for (i = 0; i < 8; i = i + 1) begin
                word_values[i] <= 4'd0;
            end

            // Initialize temp values
            for (i = 0; i < 8; i = i + 1) begin
                temp_values[i] <= 4'd0;
            end

            // Initialize sorted words
            for (i = 0; i < 8; i = i + 1) begin
                sorted_words[i] <= 40'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    word_index <= 4'd0;
                    char_index <= 3'd0;
                    valid_word_count <= 4'd0;
                    char_ready <= 1'b0;
                    if (start) begin
                        next_state <= READ_WORDS;
                    end
                end

                READ_WORDS: begin
                    if (char_valid) begin
                        current_char <= char_in;
                        char_ready <= 1'b1;
                    end

                    if (char_ready) begin
                        // Store character in buffer
                        word_buffer[word_index][char_index] <= current_char;
                        char_index <= char_index + 3'd1;
                        char_ready <= 1'b0;

                        // Check for space or end of word
                        if (current_char == 8'd32 || char_index == 3'd5) begin
                            // End of word
                            if (char_index > 3'd0) begin
                                valid_word_count <= valid_word_count + 4'd1;
                            end
                            word_index <= word_index + 4'd1;
                            char_index <= 3'd0;

                            // Check if we have 8 words or received all input
                            if (word_index == 4'd8 || (current_char == 8'd32 && !char_valid)) begin
                                next_state <= MAP_VALUES;
                            end
                        end
                    end
                end

                MAP_VALUES: begin
                    // Map each word to its numeric value
                    for (i = 0; i < 8; i = i + 1) begin
                        if (word_buffer[i][0] == "zero"[0] &&
                            word_buffer[i][1] == "zero"[1] &&
                            word_buffer[i][2] == "zero"[2] &&
                            word_buffer[i][3] == "zero"[3]) begin
                            word_values[i] <= 4'd0;
                        end else if (word_buffer[i][0] == "one"[0] &&
                                   word_buffer[i][1] == "one"[1] &&
                                   word_buffer[i][2] == "one"[2]) begin
                            word_values[i] <= 4'd1;
                        end else if (word_buffer[i][0] == "two"[0] &&
                                   word_buffer[i][1] == "two"[1] &&
                                   word_buffer[i][2] == "two"[2]) begin
                            word_values[i] <= 4'd2;
                        end else if (word_buffer[i][0] == "three"[0] &&
                                   word_buffer[i][1] == "three"[1] &&
                                   word_buffer[i][2] == "three"[2] &&
                                   word_buffer[i][3] == "three"[3] &&
                                   word_buffer[i][4] == "three"[4]) begin
                            word_values[i] <= 4'd3;
                        end else if (word_buffer[i][0] == "four"[0] &&
                                   word_buffer[i][1] == "four"[1] &&
                                   word_buffer[i][2] == "four"[2] &&
                                   word_buffer[i][3] == "four"[3]) begin
                            word_values[i] <= 4'd4;
                        end else if (word_buffer[i][0] == "five"[0] &&
                                   word_buffer[i][1] == "five"[1] &&
                                   word_buffer[i][2] == "five"[2] &&
                                   word_buffer[i][3] == "five"[3]) begin
                            word_values[i] <= 4'd5;
                        end else if (word_buffer[i][0] == "six"[0] &&
                                   word_buffer[i][1] == "six"[1] &&
                                   word_buffer[i][2] == "six"[2]) begin
                            word_values[i] <= 4'd6;
                        end else if (word_buffer[i][0] == "seven"[0] &&
                                   word_buffer[i][1] == "seven"[1] &&
                                   word_buffer[i][2] == "seven"[2] &&
                                   word_buffer[i][3] == "seven"[3] &&
                                   word_buffer[i][4] == "seven"[4]) begin
                            word_values[i] <= 4'd7;
                        end else if (word_buffer[i][0] == "eight"[0] &&
                                   word_buffer[i][1] == "eight"[1] &&
                                   word_buffer[i][2] == "eight"[2] &&
                                   word_buffer[i][3] == "eight"[3] &&
                                   word_buffer[i][4] == "eight"[4]) begin
                            word_values[i] <= 4'd8;
                        end else if (word_buffer[i][0] == "nine"[0] &&
                                   word_buffer[i][1] == "nine"[1] &&
                                   word_buffer[i][2] == "nine"[2] &&
                                   word_buffer[i][3] == "nine"[3]) begin
                            word_values[i] <= 4'd9;
                        end else begin
                            word_values[i] <= 4'd0; // Default to zero if not recognized
                        end
                    end
                    next_state <= SORT_VALUES;
                end

                SORT_VALUES: begin
                    // Bubble sort implementation
                    if (!sort_done) begin
                        if (sort_j == 4'd0) begin
                            sort_i <= sort_i + 4'd1;
                            if (sort_i == 4'd7) begin
                                sort_done <= 1'b1;
                            end
                        end

                        if (sort_i < 4'd7 && sort_j < 4'd7 - sort_i) begin
                            if (word_values[sort_j] > word_values[sort_j + 4'd1]) begin
                                // Swap
                                temp_values[0] <= word_values[sort_j];
                                word_values[sort_j] <= word_values[sort_j + 4'd1];
                                word_values[sort_j + 4'd1] <= temp_values[0];
                            end
                            sort_j <= sort_j + 4'd1;
                        end else begin
                            sort_j <= 4'd0;
                        end
                    end else begin
                        next_state <= MAP_BACK;
                    end
                end

                MAP_BACK: begin
                    // Map sorted values back to words
                    for (i = 0; i < 8; i = i + 1) begin
                        case (word_values[i])
                            4'd0: begin
                                sorted_words[i][7:0] <= zero[0];
                                sorted_words[i][15:8] <= zero[1];
                                sorted_words[i][23:16] <= zero[2];
                                sorted_words[i][31:24] <= zero[3];
                                sorted_words[i][39:32] <= 8'd0;
                            end
                            4'd1: begin
                                sorted_words[i][7:0] <= one[0];
                                sorted_words[i][15:8] <= one[1];
                                sorted_words[i][23:16] <= one[2];
                                sorted_words[i][31:24] <= 8'd0;
                                sorted_words[i][39:32] <= 8'd0;
                            end
                            4'd2: begin
                                sorted_words[i][7:0] <= two[0];
                                sorted_words[i][15:8] <= two[1];
                                sorted_words[i][23:16] <= two[2];
                                sorted_words[i][31:24] <= 8'd0;
                                sorted_words[i][39:32] <= 8'd0;
                            end
                            4'd3: begin
                                sorted_words[i][7:0] <= three[0];
                                sorted_words[i][15:8] <= three[1];
                                sorted_words[i][23:16] <= three[2];
                                sorted_words[i][31:24] <= three[3];
                                sorted_words[i][39:32] <= three[4];
                            end
                            4'd4: begin
                                sorted_words[i][7:0] <= four[0];
                                sorted_words[i][15:8] <= four[1];
                                sorted_words[i][23:16] <= four[2];
                                sorted_words[i][31:24] <= four[3];
                                sorted_words[i][39:32] <= 8'd0;
                            end
                            4'd5: begin
                                sorted_words[i][7:0] <= five[0];
                                sorted_words[i][15:8] <= five[1];
                                sorted_words[i][23:16] <= five[2];
                                sorted_words[i][31:24] <= five[3];
                                sorted_words[i][39:32] <= 8'd0;
                            end
                            4'd6: begin
                                sorted_words[i][7:0] <= six[0];
                                sorted_words[i][15:8] <= six[1];
                                sorted_words[i][23:16] <= six[2];
                                sorted_words[i][31:24] <= 8'd0;
                                sorted_words[i][39:32] <= 8'd0;
                            end
                            4'd7: begin
                                sorted_words[i][7:0] <= seven[0];
                                sorted_words[i][15:8] <= seven[1];
                                sorted_words[i][23:16] <= seven[2];
                                sorted_words[i][31:24] <= seven[3];
                                sorted_words[i][39:32] <= seven[4];
                            end
                            4'd8: begin
                                sorted_words[i][7:0] <= eight[0];
                                sorted_words[i][15:8] <= eight[1];
                                sorted_words[i][23:16] <= eight[2];
                                sorted_words[i][31:24] <= eight[3];
                                sorted_words[i][39:32] <= eight[4];
                            end
                            4'd9: begin
                                sorted_words[i][7:0] <= nine[0];
                                sorted_words[i][15:8] <= nine[1];
                                sorted_words[i][23:16] <= nine[2];
                                sorted_words[i][31:24] <= nine[3];
                                sorted_words[i][39:32] <= 8'd0;
                            end
                            default: begin
                                sorted_words[i] <= 40'd0;
                            end
                        endcase
                    end
                    word_count <= valid_word_count;
                    next_state <= OUTPUT;
                end

                OUTPUT: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase

            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b1;
            end
        end
    end
endmodule