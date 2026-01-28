module words_in_sentence(
    input clk,
    input rst_n,
    input start,
    input [799:0] sentence,
    input [6:0] length,
    output [799:0] result,
    output reg [6:0] result_len,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PARSE   = 3'd1;
    localparam [2:0] CHECK   = 3'd2;
    localparam [2:0] COPY    = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] char_index;
    reg [6:0] word_start, word_end;
    reg [6:0] result_index;
    reg [6:0] word_count;
    reg [6:0] current_word_len;
    reg [6:0] space_count;
    reg [6:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Prime lookup table for lengths 1-100
    reg [99:0] prime_lut;
    integer i;

    // Initialize prime LUT
    initial begin
        prime_lut = 100'd0;
        prime_lut[2] = 1'b1; prime_lut[3] = 1'b1; prime_lut[5] = 1'b1; prime_lut[7] = 1'b1;
        prime_lut[11] = 1'b1; prime_lut[13] = 1'b1; prime_lut[17] = 1'b1; prime_lut[19] = 1'b1;
        prime_lut[23] = 1'b1; prime_lut[29] = 1'b1; prime_lut[31] = 1'b1; prime_lut[37] = 1'b1;
        prime_lut[41] = 1'b1; prime_lut[43] = 1'b1; prime_lut[47] = 1'b1; prime_lut[53] = 1'b1;
        prime_lut[59] = 1'b1; prime_lut[61] = 1'b1; prime_lut[67] = 1'b1; prime_lut[71] = 1'b1;
        prime_lut[73] = 1'b1; prime_lut[79] = 1'b1; prime_lut[83] = 1'b1; prime_lut[89] = 1'b1;
        prime_lut[97] = 1'b1;
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            char_index <= 8'd0;
            word_start <= 7'd0;
            word_end <= 7'd0;
            result_index <= 7'd0;
            word_count <= 7'd0;
            current_word_len <= 7'd0;
            space_count <= 7'd0;
            result_len <= 7'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= PARSE;
                        char_index <= 8'd0;
                        word_start <= 7'd0;
                        word_end <= 7'd0;
                        result_index <= 7'd0;
                        word_count <= 7'd0;
                        current_word_len <= 7'd0;
                        space_count <= 7'd0;
                        result_len <= 7'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PARSE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (char_index < length) begin
                        if (sentence[char_index*8 +: 8] == 8'd32) begin
                            if (current_word_len > 0) begin
                                word_end <= char_index - 8'd1;
                                next_state <= CHECK;
                            end else begin
                                char_index <= char_index + 8'd1;
                            end
                        end else begin
                            if (current_word_len == 0) begin
                                word_start <= char_index;
                            end
                            current_word_len <= current_word_len + 8'd1;
                            char_index <= char_index + 8'd1;
                        end
                    end else begin
                        if (current_word_len > 0) begin
                            word_end <= char_index - 8'd1;
                            next_state <= CHECK;
                        end else begin
                            next_state <= DONE_STATE;
                        end
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (prime_lut[current_word_len]) begin
                        next_state <= COPY;
                    end else begin
                        current_word_len <= 7'd0;
                        char_index <= word_end + 8'd2;
                        next_state <= PARSE;
                    end
                end

                COPY: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (word_count > 0) begin
                        result[result_index*8 +: 8] <= 8'd32;
                        result_index <= result_index + 8'd1;
                        result_len <= result_len + 8'd1;
                    end
                    if (word_start <= word_end) begin
                        result[result_index*8 +: 8] <= sentence[word_start*8 +: 8];
                        result_index <= result_index + 8'd1;
                        result_len <= result_len + 8'd1;
                        word_start <= word_start + 8'd1;
                    end else begin
                        word_count <= word_count + 7'd1;
                        current_word_len <= 7'd0;
                        char_index <= word_end + 8'd2;
                        next_state <= PARSE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Default assignments for outputs
    assign result = 800'd0;

endmodule