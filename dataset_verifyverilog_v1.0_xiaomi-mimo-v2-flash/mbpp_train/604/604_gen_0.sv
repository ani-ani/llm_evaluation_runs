module reverse_words (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str [0:7],
    output reg [7:0] result [0:7],
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE = 3'd1;
    localparam [2:0] REVERSE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] word_start [0:3];  // Start indices of up to 4 words
    reg [7:0] word_end [0:3];    // End indices of up to 4 words
    reg [2:0] word_count;        // Number of words found
    reg [2:0] parse_idx;         // Current character index during parse
    reg [2:0] word_idx;          // Current word index
    reg [2:0] out_idx;           // Output character index
    reg [2:0] src_word_idx;      // Source word index during reverse
    reg [2:0] char_idx_in_word;  // Character index within current word
    reg [2:0] cycle_count;       // Cycle counter for safety

    // Parse logic: find word boundaries
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result[0] <= 8'd0; result[1] <= 8'd0; result[2] <= 8'd0; result[3] <= 8'd0;
            result[4] <= 8'd0; result[5] <= 8'd0; result[6] <= 8'd0; result[7] <= 8'd0;
            word_count <= 3'd0;
            parse_idx <= 3'd0;
            word_idx <= 3'd0;
            out_idx <= 3'd0;
            src_word_idx <= 3'd0;
            char_idx_in_word <= 3'd0;
            cycle_count <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    parse_idx <= 3'd0;
                    word_idx <= 3'd0;
                    word_count <= 3'd0;
                    cycle_count <= 3'd0;
                    if (start) begin
                        state <= PARSE;
                        // Initialize first word start
                        word_start[0] <= 8'd0;
                    end
                end

                PARSE: begin
                    // Find word boundaries
                    if (parse_idx < 8'd8) begin
                        if (parse_idx == 7) begin
                            // End of string, finish last word
                            word_end[word_count] <= 8'd7;
                            word_count <= word_count + 3'd1;
                            state <= REVERSE;
                        end else if (str[parse_idx] == 8'h20) begin
                            // Found space, finish current word
                            word_end[word_count] <= parse_idx - 8'd1;
                            word_count <= word_count + 3'd1;
                            // Start next word
                            word_idx <= word_idx + 3'd1;
                            word_start[word_idx + 3'd1] <= parse_idx + 8'd1;
                        end
                        parse_idx <= parse_idx + 8'd1;
                    end
                end

                REVERSE: begin
                    // Prepare for reverse output
                    state <= OUTPUT;
                    out_idx <= 3'd0;
                    src_word_idx <= word_count - 3'd1;  // Start with last word
                    char_idx_in_word <= 3'd0;
                    cycle_count <= cycle_count + 3'd1;
                end

                OUTPUT: begin
                    if (out_idx < 8'd8) begin
                        if (src_word_idx < word_count) begin
                            // We still have words to process
                            reg [7:0] curr_start;
                            reg [7:0] curr_end;
                            curr_start = word_start[src_word_idx];
                            curr_end = word_end[src_word_idx];

                            if (char_idx_in_word <= (curr_end - curr_start)) begin
                                // Copy character from source
                                result[out_idx] <= str[curr_start + char_idx_in_word];
                                char_idx_in_word <= char_idx_in_word + 3'd1;
                                out_idx <= out_idx + 8'd1;
                            end else begin
                                // Word finished, add space if not last output
                                if (out_idx < 8'd7 && src_word_idx > 0) begin
                                    result[out_idx] <= 8'h20;
                                    out_idx <= out_idx + 8'd1;
                                end
                                // Move to previous word
                                src_word_idx <= src_word_idx - 3'd1;
                                char_idx_in_word <= 3'd0;
                            end
                        end else begin
                            // All words processed, pad remaining with spaces
                            result[out_idx] <= 8'h20;
                            out_idx <= out_idx + 8'd1;
                        end
                    end else begin
                        state <= FINISH;
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
        end
    end

endmodule