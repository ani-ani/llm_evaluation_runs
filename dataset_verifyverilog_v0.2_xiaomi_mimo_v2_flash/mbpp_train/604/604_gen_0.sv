module reverse_words (
    input clk,
    input rst_n,
    input start,
    input [7:0][7:0] string_data,
    input [2:0] string_length,
    output reg [7:0][7:0] result_data,
    output reg [2:0] result_length,
    output reg done
);

    // States
    localparam IDLE = 2'b00;
    localparam SCAN_WORDS = 2'b01;
    localparam BUILD_RESULT = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state;

    // Buffers for words (up to 4 words in 8 chars)
    reg [2:0] word_start [0:3];
    reg [2:0] word_len [0:3];
    reg [2:0] word_count;

    // Counters
    reg [2:0] scan_idx;
    reg [2:0] word_start_idx;
    
    // Build counters
    reg [2:0] b_word_idx; // Iterates from word_count down to 1
    reg [2:0] b_char_idx;
    reg [2:0] res_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_data <= 128'b0;
            result_length <= 3'b0;
            word_count <= 3'b0;
            scan_idx <= 3'b0;
            word_start_idx <= 3'b0;
            b_word_idx <= 3'b0;
            b_char_idx <= 3'b0;
            res_idx <= 3'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SCAN_WORDS;
                        scan_idx <= 3'b0;
                        word_count <= 3'b0;
                        word_start_idx <= 3'b0;
                        result_data <= 128'b0; // Clear output buffer
                    end
                end

                SCAN_WORDS: begin
                    if (scan_idx < string_length) begin
                        if (string_data[scan_idx] == 8'h20) begin
                            // Space found, if there was a word before it, save it
                            if (scan_idx > word_start_idx) begin
                                if (word_count < 4) begin
                                    word_start[word_count] <= word_start_idx;
                                    word_len[word_count] <= scan_idx - word_start_idx;
                                    word_count <= word_count + 1'b1;
                                end
                            end
                            word_start_idx <= scan_idx + 1'b1;
                        end
                        scan_idx <= scan_idx + 1'b1;
                    end else begin
                        // End of string, check for trailing word
                        if (scan_idx > word_start_idx) begin
                            if (word_count < 4) begin
                                word_start[word_count] <= word_start_idx;
                                word_len[word_count] <= scan_idx - word_start_idx;
                                word_count <= word_count + 1'b1;
                            end
                        end
                        // Transition to Build or Done if no words
                        if (word_count > 0 || (scan_idx > word_start_idx)) begin
                            state <= BUILD_RESULT;
                            b_word_idx <= word_count; // Prepare for reverse iteration
                            res_idx <= 3'b0;
                        end else begin
                            state <= DONE;
                            done <= 1'b1;
                            result_length <= 3'b0;
                        end
                    end
                end

                BUILD_RESULT: begin
                    // Process words in reverse order (word_count-1 down to 0)
                    if (b_word_idx > 0) begin
                        // Current word is index (b_word_idx - 1)
                        if (b_char_idx < word_len[b_word_idx - 1]) begin
                            // Copy char
                            result_data[res_idx] <= string_data[word_start[b_word_idx - 1] + b_char_idx];
                            res_idx <= res_idx + 1'b1;
                            b_char_idx <= b_char_idx + 1'b1;
                        end else begin
                            // Word done, add space if more words follow
                            if (b_word_idx > 1) begin
                                result_data[res_idx] <= 8'h20;
                                res_idx <= res_idx + 1'b1;
                            end
                            // Move to next word (reverse order)
                            b_word_idx <= b_word_idx - 1'b1;
                            b_char_idx <= 3'b0;
                            // If no more words (b_word_idx becomes 0 after decrement, check here or next cycle)
                            // We decrement b_word_idx. If it becomes 0, loop terminates next cycle.
                        end
                    end else begin
                        // All words processed
                        state <= DONE;
                        done <= 1'b1;
                        result_length <= res_idx;
                    end
                end

                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end
endmodule