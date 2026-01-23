module fib4 (
input clk,
input rst_n,
input start,
input [3:0] n,
output reg [15:0] result,
output reg done
);

parameter IDLE = 2'd0,
INIT = 1,
COMPUTE = 2,
DONE =3;

reg [1:0] state;
reg [3:0] n_val;
reg [15:0] v0, v1, v2, v3;
reg [3:0] counter;

always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
n_val <= 4'd0;
v0 <= 16'd0;
v1 <= 16'd0;
v2 <= 16'd0;
v3 <= 16'd0;
counter <= 4'd0;
result <= 16'd0;
done <= 1'b0;
end else begin
case(state)
IDLE: begin
if (start) begin
state <= INIT;
end
end
INIT: begin
n_val <= n;
if (n_val == 0 || n_val ==1 || n_val ==3) begin
result <= 16'd0;
done <= 1'b1;
state <= DONE;
end else if (n_val == 2) begin
result <= 2;
done <=1'b1;
state <= DONE;
end else if (n_val >=4) begin
v0 <= 16'd0;
v1 <= 16'd0;
v2 <= 16'd2;
v3 <= 16'd0;
counter <= 4'd3;
state <= COMPUTE;
end
end
COMPUTE: begin
if (counter == n_val) begin
result <= v3;
done <=1'b1;
state <= DONE;
end else begin
reg [15:0] new_val;
new_val = v0 + v1 + v2 + v3;
v0 <= v1;
v1 <= v2;
v2 <= v3;
v3 <= new_val;
counter <= counter +1;
state <= COMPUTE;
end
end
DONE: begin
state <= DONE;
end
default: state <= IDLE;
endcase
end
end
endmodule