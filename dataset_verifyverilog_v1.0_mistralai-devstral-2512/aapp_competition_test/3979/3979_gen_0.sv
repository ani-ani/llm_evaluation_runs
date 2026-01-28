module BooklandCapitalizer(
    input clk,
    input rst_n,
    input start,
    input [3:0] n_words,
    input [3:0] word_lens [0:15],
    input [7:0] words_flat [0:255],
    input [3:0] num_letters,
    output reg result_valid,
    output reg [15:0] result_mask,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE     = 4'd0;
    localparam [3:0] PARSE    = 4'd1;
    localparam [3:0] COMPARE  = 4'd2;
    localparam [3:0] IMPLY    = 4'd3;
    localparam [3:0] VERIFY   = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;

    reg [3:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Parsed words storage
    reg [7:0] parsed_words [0:15][0:15];
    reg [3:0] current_word_idx;
    reg [3:0] current_letter_idx;
    reg [3:0] flat_idx;

    // Comparison variables
    reg [3:0] word_pair_idx;
    reg [3:0] letter_pos;
    reg [7:0] letter1, letter2;
    reg [15:0] implications [0:15];
    reg [15:0] reverse_implications [0:15];

    // 2-SAT variables
    reg [15:0] forced_true;
    reg [15:0] forced_false;
    reg [3:0] current_letter;
    reg [3:0] stack_ptr;
    reg [3:0] stack [0:15];

    // Temporary registers
    reg [7:0] temp_letter;
    reg [3:0] temp_idx;
    reg [3:0] i, j, k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            result_mask <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_word_idx <= 4'd0;
            current_letter_idx <= 4'd0;
            flat_idx <= 4'd0;
            word_pair_idx <= 4'd0;
            letter_pos <= 4'd0;
            letter1 <= 8'd0;
            letter2 <= 8'd0;
            forced_true <= 16'd0;
            forced_false <= 16'd0;
            current_letter <= 4'd0;
            stack_ptr <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                implications[i] <= 16'd0;
                reverse_implications[i] <= 16'd0;
                stack[i] <= 4'd0;
                for (j = 0; j < 16; j = j + 1) begin
                    parsed_words[i][j] <= 8'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    result_mask <= 16'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PARSE;
                    end
                end

                PARSE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (flat_idx < word_lens[current_word_idx]) begin
                        parsed_words[current_word_idx][current_letter_idx] <= words_flat[flat_idx];
                        flat_idx <= flat_idx + 4'd1;
                        current_letter_idx <= current_letter_idx + 4'd1;
                    end else begin
                        current_letter_idx <= 4'd0;
                        current_word_idx <= current_word_idx + 4'd1;
                        flat_idx <= flat_idx + 4'd1;
                        if (current_word_idx >= n_words) begin
                            current_word_idx <= 4'd0;
                            flat_idx <= 4'd0;
                            state <= COMPARE;
                        end
                    end
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (word_pair_idx < n_words - 4'd1) begin
                        if (letter_pos < word_lens[word_pair_idx] && letter_pos < word_lens[word_pair_idx + 4'd1]) begin
                            letter1 <= parsed_words[word_pair_idx][letter_pos];
                            letter2 <= parsed_words[word_pair_idx + 4'd1][letter_pos];
                            if (letter1 != letter2) begin
                                if (letter1 < letter2) begin
                                    implications[letter2] <= implications[letter2] | (1 << letter1);
                                end else begin
                                    forced_true <= forced_true | (1 << letter1);
                                    forced_false <= forced_false | (1 << letter2);
                                end
                                letter_pos <= 4'd0;
                                word_pair_idx <= word_pair_idx + 4'd1;
                            end else begin
                                letter_pos <= letter_pos + 4'd1;
                            end
                        end else begin
                            if (word_lens[word_pair_idx] > word_lens[word_pair_idx + 4'd1]) begin
                                result_valid <= 1'b0;
                                state <= DONE_STATE;
                            end else begin
                                letter_pos <= 4'd0;
                                word_pair_idx <= word_pair_idx + 4'd1;
                            end
                        end
                    end else begin
                        word_pair_idx <= 4'd0;
                        letter_pos <= 4'd0;
                        state <= IMPLY;
                    end
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                end

                IMPLY: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (current_letter < num_letters) begin
                        if ((forced_true[current_letter] || forced_false[current_letter]) && (forced_true[current_letter] && forced_false[current_letter])) begin
                            result_valid <= 1'b0;
                            state <= DONE_STATE;
                        end else if (forced_true[current_letter]) begin
                            result_mask <= result_mask | (1 << current_letter);
                        end else if (forced_false[current_letter]) begin
                            result_mask <= result_mask & ~(1 << current_letter);
                        end else begin
                            stack[stack_ptr] <= current_letter;
                            stack_ptr <= stack_ptr + 4'd1;
                        end
                        current_letter <= current_letter + 4'd1;
                    end else begin
                        current_letter <= 4'd0;
                        state <= VERIFY;
                    end
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                end

                VERIFY: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (stack_ptr > 4'd0) begin
                        stack_ptr <= stack_ptr - 4'd1;
                        temp_letter <= stack[stack_ptr];
                        if (implications[temp_letter] != 16'd0) begin
                            for (i = 0; i < 16; i = i + 1) begin
                                if (implications[temp_letter][i]) begin
                                    if (forced_false[i]) begin
                                        result_valid <= 1'b0;
                                        state <= DONE_STATE;
                                    end else if (!forced_true[i]) begin
                                        forced_true <= forced_true | (1 << i);
                                        result_mask <= result_mask | (1 << i);
                                        stack[stack_ptr] <= i;
                                        stack_ptr <= stack_ptr + 4'd1;
                                    end
                                end
                            end
                        end
                    end else begin
                        state <= DONE_STATE;
                    end
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    result_valid <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule