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
    localparam [2:0] PROCESS   = 3'd1;
    localparam [2:0] COMPARE   = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;
    localparam [2:0] ERROR     = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] word_index;
    reg [2:0] char_index;
    reg [7:0] char_present;
    reg [3:0] current_unique_count;
    reg [3:0] best_unique_count;
    reg [63:0] best_word;
    reg [7:0] current_char;
    reg [7:0] best_char;
    reg lex_smaller;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2048;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            word_index <= 4'd0;
            char_index <= 3'd0;
            char_present <= 8'd0;
            current_unique_count <= 4'd0;
            best_unique_count <= 4'd0;
            best_word <= 64'd0;
            current_char <= 8'd0;
            best_char <= 8'd0;
            lex_smaller <= 1'b0;
            cycle_count <= 8'd0;
            result <= 64'd0;
            done <= 1'b0;
            status <= 3'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    status <= 3'd0;
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= PROCESS;
                        word_index <= 4'd0;
                        char_index <= 3'd0;
                        char_present <= 8'd0;
                        current_unique_count <= 4'd0;
                        best_unique_count <= 4'd0;
                        best_word <= 64'd0;
                        status <= 3'd1;
                    end
                end

                PROCESS: begin
                    status <= 3'd1;
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= ERROR;
                        status <= 3'd3;
                    end else begin
                        // Process current character
                        current_char = words_data[word_index][char_index * 8 +: 8];
                        if (current_char >= 8'd65 && current_char <= 8'd90) begin
                            // Convert uppercase to lowercase
                            current_char = current_char + 8'd32;
                        end
                        if (current_char >= 8'd97 && current_char <= 8'd122) begin
                            // Set corresponding bit in char_present
                            char_present[current_char - 8'd97] = 1'b1;
                        end
                        // Move to next character
                        if (char_index == 3'd7) begin
                            // Count unique characters
                            integer i;
                            current_unique_count = 4'd0;
                            for (i = 0; i < 8; i = i + 1) begin
                                if (char_present[i]) begin
                                    current_unique_count = current_unique_count + 4'd1;
                                end
                            end
                            // Reset for next word
                            char_present <= 8'd0;
                            char_index <= 3'd0;
                            next_state <= COMPARE;
                        end else begin
                            char_index <= char_index + 3'd1;
                        end
                    end
                end

                COMPARE: begin
                    status <= 3'd1;
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= ERROR;
                        status <= 3'd3;
                    end else begin
                        // Compare current word with best word
                        if (current_unique_count > best_unique_count) begin
                            best_unique_count <= current_unique_count;
                            best_word <= words_data[word_index];
                        end else if (current_unique_count == best_unique_count) begin
                            // Lexicographical comparison
                            integer i;
                            lex_smaller = 1'b0;
                            for (i = 0; i < 8; i = i + 1) begin
                                current_char = words_data[word_index][i * 8 +: 8];
                                best_char = best_word[i * 8 +: 8];
                                if (current_char < best_char) begin
                                    lex_smaller = 1'b1;
                                    break;
                                end else if (current_char > best_char) begin
                                    lex_smaller = 1'b0;
                                    break;
                                end
                            end
                            if (lex_smaller) begin
                                best_word <= words_data[word_index];
                            end
                        end
                        // Move to next word
                        if (word_index == num_words - 4'd1) begin
                            next_state <= DONE_STATE;
                        end else begin
                            word_index <= word_index + 4'd1;
                            next_state <= PROCESS;
                        end
                    end
                end

                DONE_STATE: begin
                    status <= 3'd2;
                    result <= best_word;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                ERROR: begin
                    status <= 3'd3;
                    done <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    status <= 3'd0;
                end
            endcase
        end
    end
endmodule