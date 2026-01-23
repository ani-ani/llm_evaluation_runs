module factorial_trailing (input clk, input rst_n, input start, input [4:0] n, output reg [11:0] result, output reg done);
reg [63:0] fact_reg;
reg [3:0] mult_count;
reg [11:0] result_reg;
reg [2:0] state_reg;
reg done_reg;
localparam IDLE = 3'd0;
localparam COMPUTE_FACT = 3'd1;
localparam REMOVE_ZEROES = 3'd2;
localparam EXTRACT_DIGITS = 3'd3;
localparam DONE_STATE = 3'd4;
always @(posedge clk) begin
if (!rst_n) begin
fact_reg <= 64'd0;
mult_count <= 4'd2;
state_reg <= IDLE;
result_reg <= 12'd0;
done_reg <= 1'b0;
end
else begin
if (state_reg == IDLE) begin
if (start) begin
state_reg <= COMPUTE_FACT;
fact_reg <= 64'd1;
mult_count <= 4'd2;
end
end
else if (state_reg == COMPUTE_FACT) begin
if (mult_count <= n) begin
fact_reg <= fact_reg * mult_count;
mult_count <= mult_count + 1;
end
else begin
state_reg <= REMOVE_ZEROES;
end
end
else if (state_reg == REMOVE_ZEROES) begin
if (fact_reg % 10 == 0) begin
fact_reg <= fact_reg / 10;
end
else begin
state_reg <= EXTRACT_DIGITS;
end
end
else if (state_reg == EXTRACT_DIGITS) begin
integer num = fact_reg % 1000;
integer hundreds = num / 100;
integer tens = (num / 10) % 10;
integer units = num % 10;
result_reg <= (hundreds << 8) | (tens << 4) | units;
state_reg <= DONE_STATE;
end
else if (state_reg == DONE_STATE) begin
done_reg <= 1'b1;
end
end
end
assign result = result_reg;
assign done = done_reg;
endmodule