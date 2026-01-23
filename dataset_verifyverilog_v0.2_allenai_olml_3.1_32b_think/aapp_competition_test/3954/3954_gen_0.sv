module max_swap_subarray (input clk, input rst_n, input start, input [7:0] a_0, input [7:0] a_1, input [7:0] a_2, input [7:0] a_3, input [7:0] a_4, input [7:0] a_5, input [7:0] a_6, input [7:0] a_7, input [2:0] k_in, output reg [15:0] result, output reg done);
reg [7:0] array_reg [7:0];
reg [15:0] best_result;
reg [2:0] l, r;
reg [3:0] state;
localparam IDLE = 4'd0, INIT = 4'd1, ITER_L = 4'd2, ITER_R = 4'd3, SORT_INNER =4'd4, SORT_OUTER=4'd5, SWAP_LOOP=4'd6, UPDATE_BEST=4'd7, DONE=4'd8;
always_ff @(posedge clk) begin
if (!rst_n) begin
array_reg <= 8'b0;
best_result <= 16'b0;
l <= 3'b000;
r <= 3'b000;
state <= IDLE;
done <= 1'b0;
result <= 16'b0;
end else begin
case (state)
IDLE: begin
if (start) begin
state <= INIT;
end else begin
state <= IDLE;
end
end
INIT: begin
array_reg <= {a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7};
best_result <= array_reg[0];
l <= 3'b000;
r <= 3'b000;
state <= ITER_L;
end
ITER_L: begin
if (l < 8) begin
r <= l;
state <= ITER_R;
end else begin
state <= DONE;
end
end
ITER_R: begin
if (r < 8) begin
r <= r +1;
state <= ITER_R;
end else begin
r <= 3'b000;
l <= l +1;
if (l <8) begin
state <= ITER_R;
end else begin
state <= UPDATE_BEST;
end
end
end
UPDATE_BEST: begin
state <= DONE;
end
DONE: begin
done <= 1'b1;
state <= DONE;
end
endcase
end
endmodule