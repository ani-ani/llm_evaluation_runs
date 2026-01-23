module digit_sum_optimizer (input clk, input rst_n, input start, input [11:0] n, output reg [7:0] result, output reg done);
function automatic [7:0] digit_sum;
input [11:0] x;
begin
integer temp;
temp = x;
digit_sum = 0;
while (temp > 0) begin
digit_sum += temp % 10;
temp = temp / 10;
end
endfunction
reg [2:0] state_reg;
reg [11:0] a;
reg [7:0] max_sum;
reg done_reg;
reg [7:0] result_reg;
assign result = result_reg;
always @(posedge clk) begin
if (!rst_n) begin
state_reg <= 3'd0;
a <= 12'b0;
max_sum <= 8'b0;
done_reg <= 1'b0;
result_reg <= 8'b0;
end else begin
case (state_reg)
3'd0: begin 
if (start) state_reg <= 3'd1; 
end
3'd1: begin 
a <= 12'b0;
max_sum <= 8'b0;
state_reg <= 3'd3; 
end
3'd2: begin 
state_reg <= 3'd3; 
end
3'd3: begin 
if (a > n) begin
state_reg <= 3'd4; 
done_reg <= 1'b1;
result_reg <= max_sum;
end else begin
int temp_sum;
temp_sum = digit_sum(a) + digit_sum(n - a);
if (temp_sum > max_sum) begin
max_sum <= temp_sum;
end
a <= a + 1;
state_reg <= 3'd2; 
end
end
3'd4: begin 
end
endcase
end
end
endmodule
