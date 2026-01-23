module words_in_sentence (
    input clk,
    input rst_n,
    input start,
    input [127:0] sentence,
    input [7:0] valid_len,
    output reg [127:0] result,
    output reg [7:0] result_len,
    output reg done
);

localparam IDLE = 2'd0;
localparam PROCESSING = 2'd1;
localparam DONE = 2'd2;

reg [1:0] state;
reg [7:0] idx;
reg [7:0] word_start;
reg [7:0] word_len;
reg [7:0] res_idx;
reg in_word;
reg space_needed;

wire [15:0] prime_table;
assign prime_table = 16'b0000000000000100;

wire [7:0] current_char;
assign current_char = sentence[(idx*8) +: 8];

wire current_len_is_prime;
assign current_len_is_prime = (word_len > 1) && (word_len <= 15) ? prime_table[word_len] : 0;

wire is_space;
assign is_space = (current_char == 8'h20);

wire is_end;
assign is_end = (idx >= valid_len);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        idx <= 8'd0;
        word_start <= 8'd0;
        word_len <= 8'd0;
        res_idx <= 8'd0;
        in_word <= 1'b0;
        space_needed <= 1'b0;
        done <= 1'b0;
        result <= 128'd0;
        result_len <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= PROCESSING;
                    idx <= 8'd0;
                    word_start <= 8'd0;
                    word_len <= 8'd0;
                    res_idx <= 8'd0;
                    in_word <= 1'b0;
                    space_needed <= 1'b0;
                    done <= 1'b0;
                    result <= 128'd0;
                    result_len <= 8'd0;
                end
            end

            PROCESSING: begin
                if (!is_end) begin
                    if (is_space) begin
                        if (in_word) begin
                            if (current_len_is_prime) begin
                                if (space_needed) begin
                                    result[(res_idx*8) +: 8] <= 8'h20;
                                    res_idx <= res_idx + 1'd1;
                                end
                                result[(res_idx*8) +: (word_len*8)] <= sentence[(word_start*8) +: (word_len*8)];
                                res_idx <= res_idx + word_len;
                                space_needed <= 1'b1;
                            end
                            in_word <= 1'b0;
                            word_len <= 8'd0;
                        end
                    end else begin
                        if (!in_word) begin
                            word_start <= idx;
                            in_word <= 1'b1;
                            word_len <= 8'd1;
                        end else begin
                            word_len <= word_len + 1'd1;
                        end
                    end
                    idx <= idx + 1'd1;
                end else begin
                    if (in_word) begin
                        if (current_len_is_prime) begin
                            if (space_needed) begin
                                result[(res_idx*8) +: 8] <= 8'h20;
                                res_idx <= res_idx + 1'd1;
                            end
                            result[(res_idx*8) +: (word_len*8)] <= sentence[(word_start*8) +: (word_len*8)];
                            res_idx <= res_idx + word_len;
                        end
                    end
                    result_len <= res_idx;
                    state <= DONE;
                end
            end

            DONE: begin
                done <= 1'b1;
                if (!start) begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            end
        endcase
    end
end

endmodule