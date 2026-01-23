module words_string_splitter (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    output reg [7:0] words [0:7],
    output reg [2:0] word_count,
    output reg done,
    output reg error
);

localparam IDLE = 3'd0, SKIP_DELIM = 3'd1, READ_WORD = 3'd2, CHECK_DELIM = 3'd3, DONE = 3'd4, ERROR = 3'd5;

reg [2:0] state;
reg [2:0] word_count;
reg [2:0] current_word_idx;
reg [2:0] current_char_count;
reg [7:0] words [0:7];

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        word_count <= 3'd0;
        current_word_idx <= 3'd0;
        current_char_count <= 3'd0;
        words[0] <= 8'd0;
        words[1] <= 8'd0;
        words[2] <= 8'd0;
        words[3] <= 8'd0;
        words[4] <= 8'd0;
        words[5] <= 8'd0;
        words[6] <= 8'd0;
        words[7] <= 8'd0;
        error <= 1'b0;
        done <= 1'b0;
    end else begin
        error <= (state == ERROR);
        done <= (state == DONE);

        case (state)
            IDLE: begin
                if (start == 1'b1) begin
                    state <= SKIP_DELIM;
                end else begin
                    state <= IDLE;
                end
            end
            SKIP_DELIM: begin
                if (valid_in == 1'b0) begin
                    state <= SKIP_DELIM;
                end else begin
                    if (char_in == 8'h20 || char_in == 8'h2C) begin
                        state <= SKIP_DELIM;
                    end else begin
                        if (word_count < 8) begin
                            current_word_idx <= word_count;
                            words[current_word_idx] <= char_in;
                            current_char_count <= 1;
                            state <= READ_WORD;
                        end else begin
                            state <= ERROR;
                        end
                    end
                end
            end
            READ_WORD: begin
                if (valid_in == 1'b0) begin
                    state <= READ_WORD;
                end else begin
                    if (char_in == 8'h20 || char_in == 8'h2C) begin
                        if (current_char_count > 8) begin
                            state <= ERROR;
                        end else begin
                            word_count <= word_count + 1;
                            state <= CHECK_DELIM;
                        end
                    end else begin
                        if (current_char_count < 8) begin
                            words[current_word_idx] <= char_in;
                            current_char_count <= current_char_count + 1;
                            state <= READ_WORD;
                        end else begin
                            state <= ERROR;
                        end
                    end
                end
            end
            CHECK_DELIM: begin
                if (valid_in == 1'b0) begin
                    if (error == 1'b0) begin
                        state <= DONE;
                    end else begin
                        state <= ERROR;
                    end
                end else begin
                    if (char_in == 8'h20 || char_in == 8'h2C) begin
                        state <= CHECK_DELIM;
                    end else begin
                        if (word_count < 8) begin
                            current_word_idx <= word_count;
                            words[current_word_idx] <= char_in;
                            current_char_count <= 1;
                            state <= READ_WORD;
                        end else begin
                            state <= ERROR;
                        end
                    end
                end
            end
            DONE: begin
                state <= DONE;
            end
            ERROR: begin
                state <= ERROR;
            end
        endcase
    end
end