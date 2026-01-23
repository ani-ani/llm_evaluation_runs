module bulbasaur_counter (
    input clk,
    input rst_n,
    input start,
    input [127:0] str_input,
    input [7:0] str_len,
    output reg [7:0] result,
    output reg done 
);

reg [2:0] state;
reg [7:0] count_B, count_u, count_l, count_b, count_a, count_s, count_r;
reg [3:0] char_idx;
reg [1:0] done_countdown;

parameter IDLE = 3'd0,
        COUNTING = 3'd1,
        COMPUTING = 3'd2,
        DONE = 3'd3;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        char_idx <= 8'd0;
        count_B <= 8'd0;
        count_u <= 8'd0;
        count_l <= 8'd0;
        count_b <= 8'd0;
        count_a <= 8'd0;
        count_s <= 8'd0;
        count_r <= 8'd0;
        result <= 8'd0;
        done <= 1'b0;
        done_countdown <= 2'd2;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= COUNTING;
            end
        end
        else if (state == COUNTING) begin
            if (char_idx < str_len) begin
                reg [7:0] char;
                char = str_input[(char_idx*8 + 7) : char_idx*8];
                if (char == 8'h42) count_B++;
                else if (char == 8'h75) count_u++;
                else if (char == 8'h6C) count_l++;
                else if (char == 8'h62) count_b++;
                else if (char == 8'h61) count_a++;
                else if (char == 8'h73) count_s++;
                else if (char == 8'h72) count_r++;
                char_idx <= char_idx + 1;
            end
            if (char_idx >= str_len) begin
                state <= COMPUTING;
            end
        end
        else if (state == COMPUTING) begin
            result <= count_B;
            if (count_u >> 1 < result) result <= count_u >> 1;
            if (count_l < result) result <= count_l;
            if (count_b < result) result <= count_b;
            if (count_a >> 1 < result) result <= count_a >> 1;
            if (count_s < result) result <= count_s;
            if (count_r < result) result <= count_r;
            state <= DONE;
        end
        else if (state == DONE) begin
            if (done_countdown == 0) begin
                done <= 1'b1;
            end else begin
                done_countdown <= done_countdown - 1;
                done <= 1'b0;
            end
        end
    end
end
endmodule