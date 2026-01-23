module multiples_counter (
input clk,
input rst_n,
input start,
input [7:0] X,
input [7:0] A,
input [13:0] B,
input [9:0] allowed,
output reg [15:0] result,
output reg done
);
function automatic is_valid;
input [13:0] num,
input [9:0] allowed;
begin
is_valid = 1;
reg [13:0] temp = num;
reg [3:0] digit0, digit1, digit2, digit3, digit4;
if (temp !=0) begin
digit0 = temp % 10;
if (!allowed[digit0]) is_valid = 0;
temp = temp / 10;
end
if (temp !=0) begin
digit1 = temp % 10;
if (!allowed[digit1]) is_valid = 0;
temp = temp / 10;
end
if (temp !=0) begin
digit2 = temp % 10;
if (!allowed[digit2]) is_valid = 0;
temp = temp / 10;
end
if (temp !=0) begin
digit3 = temp % 10;
if (!allowed[digit3]) is_valid = 0;
temp = temp / 10;
end
if (temp !=0) begin
digit4 = temp % 10;
if (!allowed[digit4]) is_valid = 0;
temp = temp / 10;
end
endfunction
always @(*) begin
if (!rst_n) begin
current_num <= 0;
state <= 3'd0;
result <= 0;
done <= 0;
end
end
always @(posedge clk) begin
if (!rst_n) begin
state <= 3'd0;
end else begin
case (state)
3'd0: begin
if (start == 1) state <= 3'd1;
else state <= 3'd0;
end
3'd1: begin
current_num <= A;
state <= 3'd2;
end
3'd2: begin
if (current_num > B) begin
state <= 3'd4;
done <= 1;
end else if (current_num % X != 0) begin
state <= 3'd3;
end else begin
if (is_valid(current_num, allowed)) begin
result <= result + 1;
end
state <= 3'd3;
end
end
3'd3: begin
current_num <= current_num + 1;
state <= 3'd2;
end
3'd4: state <= 3'd4;
default: state <= 3'd0;
endcase
end
end
endmodule