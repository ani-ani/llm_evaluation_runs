module resistance_calculator (
input clk,
input rst_n, // Active-low reset
input start,
input [63:0] a,
input [63:0] b,
output reg [63:0] result,
output reg done
);

reg [63:0] current_a, current_b, sum;
reg [2:0] state;

localparam IDLE = 2'd0,
CALCULATE = 2'd1,
DONE = 2'd2;

always @(posedge clk) begin
if (!rst_n) begin
current_a <= 64'd0;
current_b <= 64'd0;
sum <= 64'd0;
state <= IDLE;
done <= 1'b0;
result <= 64'd0;
end else begin
case (state)
IDLE: begin
if (start) begin
current_a <= a;
current_b <= b;
sum <= 64'd0;
state <= CALCULATE;
done <= 1'b0;
result <= 64'd0;
end else begin
state <= IDLE;
done <= 1'b0;
result <= 64'd0;
end
end
CALCULATE: begin
if (current_b == 64'd0) begin
state <= DONE;
done <= 1'b1;
result <= sum;
current_a <= 64'd0;
current_b <= 64'd0;
end else begin
if (current_a < current_b) begin
{current_a, current_b} = {current_b, current_a};
end
integer quotient = current_a / current_b;
integer remainder = current_a % current_b;
sum <= sum + quotient;
current_a <= current_b;
current_b <= remainder;
state <= CALCULATE;
done <= 1'b0;
result <= 64'd0;
end
end
DONE: begin
state <= DONE;
done <= 1'b1;
result <= sum;
end
endcase
end
end
endmodule