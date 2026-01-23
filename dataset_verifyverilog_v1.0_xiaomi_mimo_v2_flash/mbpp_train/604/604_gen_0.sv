module reverse_words #(
    parameter MAX_STR_LEN = 16,
    parameter CHAR_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [CHAR_WIDTH-1:0] char_in [0:MAX_STR_LEN-1],
    output reg [CHAR_WIDTH-1:0] char_out [0:MAX_STR_LEN-1],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE = 3'd1;
    localparam [2:0] REVERSE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] i, j, k; // Loop counters
    reg [7:0] word_start [0:MAX_STR_LEN-1]; // Start indices of words
    reg [7:0] word_end [0:MAX_STR_LEN-1];   // End indices of words
    reg [7:0] word_count;
    reg [7:0] output_idx;
    reg [7:0] current_word;
    reg in_word;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // FSM next state and output logic
    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: begin
                if (start)
                    next_state = PARSE;
                else
                    next_state = IDLE;
            end

            PARSE: begin
                // Parse until all input is scanned
                if (i >= MAX_STR_LEN)
                    next_state = REVERSE;
                else
                    next_state = PARSE;
            end

            REVERSE: begin
                // Reverse word order logic
                if (k >= word_count)
                    next_state = OUTPUT;
                else
                    next_state = REVERSE;
            end

            OUTPUT: begin
                // Output words with spaces
                if (output_idx >= MAX_STR_LEN || (output_idx >= word_count * 2 && output_idx >= MAX_STR_LEN))
                    next_state = FINISH;
                else
                    next_state = OUTPUT;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 8'd0;
            j <= 8'd0;
            k <= 8'd0;
            word_count <= 8'd0;
            output_idx <= 8'd0;
            current_word <= 8'd0;
            in_word <= 1'b0;
            // Initialize output array
            for (int init_i = 0; init_i < MAX_STR_LEN; init_i = init_i + 1) begin
                char_out[init_i] <= 8'd0;
                word_start[init_i] <= 8'd0;
                word_end[init_i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    i <= 8'd0;
                    word_count <= 8'd0;
                    in_word <= 1'b0;
                end

                PARSE: begin
                    // Detect word boundaries (space = 0x20)
                    if (i < MAX_STR_LEN) begin
                        if (char_in[i] != 8'h20 && !in_word) begin
                            // Start of new word
                            if (word_count < MAX_STR_LEN) begin
                                word_start[word_count] <= i;
                                in_word <= 1'b1;
                            end
                        end else if (char_in[i] == 8'h20 && in_word) begin
                            // End of word
                            if (word_count < MAX_STR_LEN) begin
                                word_end[word_count] <= i - 8'd1;
                                word_count <= word_count + 8'd1;
                                in_word <= 1'b0;
                            end
                        end
                        i <= i + 8'd1;
                    end
                    // Handle last word if input doesn't end with space
                    if (i == MAX_STR_LEN && in_word) begin
                        if (word_count < MAX_STR_LEN) begin
                            word_end[word_count] <= MAX_STR_LEN - 8'd1;
                            word_count <= word_count + 8'd1;
                            in_word <= 1'b0;
                        end
                    end
                end

                REVERSE: begin
                    // Prepare for output by processing words in reverse order
                    if (k < word_count) begin
                        current_word <= word_count - k - 8'd1;
                        output_idx <= 8'd0;
                        j <= 8'd0;
                        k <= k + 8'd1;
                    end
                end

                OUTPUT: begin
                    // Output words with single space between them
                    if (output_idx < MAX_STR_LEN) begin
                        if (current_word < word_count && j < (word_end[current_word] - word_start[current_word] + 8'd1)) begin
                            // Output character from word
                            char_out[output_idx] <= char_in[word_start[current_word] + j];
                            output_idx <= output_idx + 8'd1;
                            j <= j + 8'd1;
                        end else if (current_word > 0 && output_idx < MAX_STR_LEN) begin
                            // Add space between words
                            char_out[output_idx] <= 8'h20;
                            output_idx <= output_idx + 8'd1;
                            current_word <= current_word - 8'd1;
                            j <= 8'd0;
                        end else begin
                            // Fill remaining positions with zeros
                            char_out[output_idx] <= 8'd0;
                            output_idx <= output_idx + 8'd1;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                end
            endcase

            // Timeout protection
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
                state <= FINISH;
                done <= 1'b1;
            end
        end
    end

endmodule