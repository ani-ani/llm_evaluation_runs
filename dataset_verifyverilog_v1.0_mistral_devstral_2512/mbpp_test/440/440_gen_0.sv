module adverb_finder(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    input sentence_end,
    output reg found,
    output reg [7:0] start_pos,
    output reg [7:0] end_pos,
    output reg [127:0] adverb,
    output reg done,
    output reg error
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SEARCH = 3'd1;
    localparam [2:0] FOUND_ADVERB = 3'd2;
    localparam [2:0] WAIT_END = 3'd3;
    localparam [2:0] COMPLETE = 3'd4;

    reg [2:0] state;
    reg [7:0] char_pos;
    reg [7:0] word_start;
    reg [7:0] word_end;
    reg [7:0] adverb_start;
    reg [7:0] adverb_end;
    reg [7:0] adverb_index;
    reg [127:0] adverb_buffer;
    reg [7:0] char_buffer [0:15];
    reg [3:0] char_count;
    reg [7:0] i;
    reg is_word;
    reg is_alphabetic;
    reg [7:0] prev_char;
    reg [7:0] prev_prev_char;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_pos <= 8'd0;
            word_start <= 8'd0;
            word_end <= 8'd0;
            adverb_start <= 8'd0;
            adverb_end <= 8'd0;
            adverb_index <= 8'd0;
            adverb_buffer <= 128'd0;
            for (i = 0; i < 16; i = i + 1) begin
                char_buffer[i] <= 8'd0;
            end
            char_count <= 4'd0;
            is_word <= 1'b0;
            is_alphabetic <= 1'b0;
            prev_char <= 8'd0;
            prev_prev_char <= 8'd0;
            found <= 1'b0;
            start_pos <= 8'd0;
            end_pos <= 8'd0;
            adverb <= 128'd0;
            done <= 1'b0;
            error <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    found <= 1'b0;
                    done <= 1'b0;
                    error <= 1'b0;
                    if (start) begin
                        state <= SEARCH;
                        char_pos <= 8'd0;
                        word_start <= 8'd0;
                        word_end <= 8'd0;
                        adverb_start <= 8'd0;
                        adverb_end <= 8'd0;
                        adverb_index <= 8'd0;
                        adverb_buffer <= 128'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            char_buffer[i] <= 8'd0;
                        end
                        char_count <= 4'd0;
                        is_word <= 1'b0;
                        is_alphabetic <= 1'b0;
                        prev_char <= 8'd0;
                        prev_prev_char <= 8'd0;
                    end
                end

                SEARCH: begin
                    if (char_valid) begin
                        // Check if current character is alphabetic
                        is_alphabetic = (char_in >= 8'd65 && char_in <= 8'd90) || 
                                       (char_in >= 8'd97 && char_in <= 8'd122);

                        // Determine if we're in a word
                        if (is_alphabetic) begin
                            if (!is_word) begin
                                // Start of new word
                                word_start <= char_pos;
                                is_word <= 1'b1;
                                char_count <= 4'd0;
                                // Reset character buffer
                                for (i = 0; i < 16; i = i + 1) begin
                                    char_buffer[i] <= 8'd0;
                                end
                            end
                            // Store character in buffer
                            if (char_count < 4'd16) begin
                                char_buffer[char_count] <= char_in;
                                char_count <= char_count + 4'd1;
                            end
                            // Check for 'ly' ending (minimum 3 characters)
                            if (char_count >= 4'd3 && 
                                char_in == 8'd108 && 
                                prev_char == 8'd121) begin
                                // Found adverb ending in 'ly'
                                adverb_start <= word_start;
                                adverb_end <= char_pos;
                                adverb_index <= 8'd0;
                                // Copy adverb to buffer
                                for (i = 0; i < char_count; i = i + 1) begin
                                    adverb_buffer[(i*8)+:8] <= char_buffer[i];
                                end
                                state <= FOUND_ADVERB;
                            end
                        end else begin
                            // Not alphabetic - end of word
                            if (is_word) begin
                                word_end <= char_pos - 8'd1;
                                is_word <= 1'b0;
                            end
                        end

                        // Update previous characters
                        prev_prev_char <= prev_char;
                        prev_char <= char_in;
                        char_pos <= char_pos + 8'd1;
                    end

                    if (sentence_end) begin
                        if (adverb_start == 8'd0) begin
                            error <= 1'b1;
                        end
                        state <= WAIT_END;
                    end
                end

                FOUND_ADVERB: begin
                    found <= 1'b1;
                    start_pos <= adverb_start;
                    end_pos <= adverb_end;
                    adverb <= adverb_buffer;
                    if (sentence_end) begin
                        state <= WAIT_END;
                    end
                end

                WAIT_END: begin
                    if (sentence_end) begin
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule