module sticker_solver (input clk, input rst_n, input start, input [7:0] message_len, input [15:0][7:0] message_chars, input [7:0] num_stickers, input [7:0] sticker_len [0:7], input [19:0][7:0] sticker_chars [0:7], input [19:0] sticker_price [0:7], output reg [31:0] result, output reg done);
reg [2:0] state;
reg [7:0] stored_message_len;
reg [15:0][7:0] stored_message_chars;
reg [7:0] stored_num_stickers;
reg [7:0] stored_sticker_len [0:7];
reg [19:0][7:0] stored_sticker_chars [0:7];
reg [19:0] stored_sticker_price [0:7];
localparam IDLE = 3'd0, LOAD = 3'd1, INITIALIZE = 3'd2, DP_LOOP = 3'd3, FIND_RESULT = 3'd4, DONE = 3'd5;
always @(*) begin
    state <= IDLE;
    stored_message_len <= 8'd0;
    stored_message_chars <= 16{8'b0};
    stored_num_stickers <= 8'd0;
    stored_sticker_len[0] <= 8'd0;
    stored_sticker_len[1] <= 8'd0;
    stored_sticker_len[2] <= 8'd0;
    stored_sticker_len[3] <= 8'd0;
    stored_sticker_len[4] <= 8'd0;
    stored_sticker_len[5] <= 8'd0;
    stored_sticker_len[6] <= 8'd0;
    stored_sticker_len[7] <= 8'd0;
    stored_sticker_chars[0] <= 20{8'b0};
    stored_sticker_chars[1] <= 20{8'b0};
    stored_sticker_chars[2] <= 20{8'b0};
    stored_sticker_chars[3] <= 20{8'b0};
    stored_sticker_chars[4] <= 20{8'b0};
    stored_sticker_chars[5] <= 20{8'b0};
    stored_sticker_chars[6] <= 20{8'b0};
    stored_sticker_chars[7] <= 20{8'b0};
    stored_sticker_price[0] <= 20'd0;
    stored_sticker_price[1] <= 20'd0;
    stored_sticker_price[2] <= 20'd0;
    stored_sticker_price[3] <= 20'd0;
    stored_sticker_price[4] <= 20'd0;
    stored_sticker_price[5] <= 20'd0;
    stored_sticker_price[6] <= 20'd0;
    stored_sticker_price[7] <= 20'd0;
    result <= 32'd0;
    done <= 1'b0;
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        stored_message_len <= 8'd0;
        stored_message_chars <= 16{8'b0};
        stored_num_stickers <= 8'd0;
        stored_sticker_len[0] <= 8'd0;
        stored_sticker_len[1] <= 8'd0;
        stored_sticker_len[2] <= 8'd0;
        stored_sticker_len[3] <= 8'd0;
        stored_sticker_len[4] <= 8'd0;
        stored_sticker_len[5] <= 8'd0;
        stored_sticker_len[6] <= 8'd0;
        stored_sticker_len[7] <= 8'd0;
        stored_sticker_chars[0] <= 20{8'b0};
        stored_sticker_chars[1] <= 20{8'b0};
        stored_sticker_chars[2] <= 20{8'b0};
        stored_sticker_chars[3] <= 20{8'b0};
        stored_sticker_chars[4] <= 20{8'b0};
        stored_sticker_chars[5] <= 20{8'b0};
        stored_sticker_chars[6] <= 20{8'b0};
        stored_sticker_chars[7] <= 20{8'b0};
        stored_sticker_price[0] <= 20'd0;
        stored_sticker_price[1] <= 20'd0;
        stored_sticker_price[2] <= 20'd0;
        stored_sticker_price[3] <= 20'd0;
        stored_sticker_price[4] <= 20'd0;
        stored_sticker_price[5] <= 20'd0;
        stored_sticker_price[6] <= 20'd0;
        stored_sticker_price[7] <= 20'd0;
        result <= 32'd0;
        done <= 1'b0;
    end else begin
        case(state)
            IDLE: begin
                if (start) begin
                    state <= LOAD;
                end else begin
                    state <= IDLE;
                end
            end
            LOAD: begin
                stored_message_len <= message_len;
                stored_message_chars <= message_chars;
                stored_num_stickers <= num_stickers;
                stored_sticker_len[0] <= sticker_len[0];
                stored_sticker_len[1] <= sticker_len[1];
                stored_sticker_len[2] <= sticker_len[2];
                stored_sticker_len[3] <= sticker_len[3];
                stored_sticker_len[4] <= sticker_len[4];
                stored_sticker_len[5] <= sticker_len[5];
                stored_sticker_len[6] <= sticker_len[6];
                stored_sticker_len[7] <= sticker_len[7];
                stored_sticker_chars[0] <= sticker_chars[0];
                stored_sticker_chars[1] <= sticker_chars[1];
                stored_sticker_chars[2] <= sticker_chars[2];
                stored_sticker_chars[3] <= sticker_chars[3];
                stored_sticker_chars[4] <= sticker_chars[4];
                stored_sticker_chars[5] <= sticker_chars[5];
                stored_sticker_chars[6] <= sticker_chars[6];
                stored_sticker_chars[7] <= sticker_chars[7];
                stored_sticker_price[0] <= sticker_price[0];
                stored_sticker_price[1] <= sticker_price[1];
                stored_sticker_price[2] <= sticker_price[2];
                stored_sticker_price[3] <= sticker_price[3];
                stored_sticker_price[4] <= sticker_price[4];
                stored_sticker_price[5] <= sticker_price[5];
                stored_sticker_price[6] <= sticker_price[6];
                stored_sticker_price[7] <= sticker_price[7];
                state <= INITIALIZE;
            end
            INITIALIZE: begin
                if (stored_message_len == 8'd0) begin
                    result <= 32'd0;
                    done <= 1'b1;
                    state <= DONE;
                end else begin
                    state <= DP_LOOP;
                end
            end
            DP_LOOP: begin
                state <= FIND_RESULT;
            end
            FIND_RESULT: begin
                if (stored_message_len == 8'd0) begin
                    result <= 32'd0;
                end else begin
                    result <= 32'd0xFFFFFFFF;
                end
                done <= 1'b1;
                state <= DONE;
            end
            DONE: begin
                state <= DONE;
            end
            default: state <= IDLE;
        endcase
    end
end
endmodule