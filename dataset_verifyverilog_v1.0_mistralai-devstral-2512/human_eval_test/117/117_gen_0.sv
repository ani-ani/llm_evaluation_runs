module consonant_counter(
    input clk,
    input rst_n,
    input start,
    input [511:0] input_string,
    input [3:0] n,
    input [5:0] len,
    output reg result_found,
    output reg [127:0] result_word,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] OUTPUT = 3'd2;
    localparam [2:0] DONE = 3'd3;

    // Registers
    reg [2:0] state, next_state;
    reg [5:0] char_index;
    reg [3:0] word_index;
    reg [7:0] current_char;
    reg [7:0] word_buffer [0:15];
    reg [3:0] consonant_count;
    reg [5:0] cycle_count;
    reg [5:0] max_cycles;

    // Vowel check function
    function is_vowel;
        input [7:0] c;
        begin
            is_vowel = (c == 8'd97) || (c == 8'd101) || (c == 8'd105) || (c == 8'd111) || (c == 8'd117) ||
                      (c == 8'd65) || (c == 8'd69) || (c == 8'd73) || (c == 8'd79) || (c == 8'd85);
        end
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_index <= 6'd0;
            word_index <= 4'd0;
            current_char <= 8'd0;
            consonant_count <= 4'd0;
            result_found <= 1'b0;
            result_word <= 128'd0;
            done <= 1'b0;
            cycle_count <= 6'd0;
            max_cycles <= 6'd200;

            // Initialize word buffer
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                word_buffer[i] <= 8'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    result_found <= 1'b0;
                    done <= 1'b0;
                    char_index <= 6'd0;
                    word_index <= 4'd0;
                    consonant_count <= 4'd0;
                    cycle_count <= 6'd0;

                    // Initialize word buffer
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        word_buffer[i] <= 8'd0;
                    end

                    if (start) begin
                        next_state <= PROCESS;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 6'd1;

                    // Check if we've reached the end of the string
                    if (char_index >= len) begin
                        next_state <= DONE;
                    end else begin
                        // Get current character
                        current_char <= input_string[(char_index * 8) +: 8];

                        // Check if it's a space or end of string
                        if (current_char == 8'd32 || char_index == len - 6'd1) begin
                            // Check consonant count
                            if (consonant_count == n) begin
                                // Output the word
                                integer i;
                                for (i = 0; i < 16; i = i + 1) begin
                                    if (i < word_index)
                                        result_word[(i * 8) +: 8] <= word_buffer[i];
                                    else
                                        result_word[(i * 8) +: 8] <= 8'd0;
                                end
                                next_state <= OUTPUT;
                            end else begin
                                // Reset for next word
                                word_index <= 4'd0;
                                consonant_count <= 4'd0;
                                next_state <= PROCESS;
                            end
                            char_index <= char_index + 6'd1;
                        end else begin
                            // Add character to word buffer
                            word_buffer[word_index] <= current_char;
                            word_index <= word_index + 4'd1;

                            // Count consonants
                            if (!is_vowel(current_char)) begin
                                consonant_count <= consonant_count + 4'd1;
                            end

                            char_index <= char_index + 6'd1;
                            next_state <= PROCESS;
                        end
                    end

                    // Safety check for max cycles
                    if (cycle_count >= max_cycles) begin
                        next_state <= DONE;
                    end
                end

                OUTPUT: begin
                    result_found <= 1'b1;
                    next_state <= PROCESS;
                end

                DONE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    result_found <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule