module is_prime (
input clk,
input rst_n,
input start,
input [15:0] n,
output reg is_prime_result,
output reg done);

reg [15:0] n_reg;
reg [15:0] d_reg;
reg [2:0] state;

localparam IDLE = 3'd0,
INIT = 3'd1,
CHECK_EVEN = 3'd2,
COMPUTE_SQRT = 3'd3,
ITERATE = 3'd4,
DIVIDE = 3'd5,
DONE = 3'd6;

always @(posedge clk) begin
if (!rst_n) begin
n_reg <= 16'd0;
d_reg <= 16'd0;
is_prime_result <= 1'b0;
done <= 1'b0;
state <= IDLE;
end else begin
case (state)
IDLE: begin
done <= 1'b0;
if (start) begin
n_reg <= n;
state <= INIT;
end
end
INIT: begin
state <= CHECK_EVEN;
end
CHECK_EVEN: begin
done <= 1'b0;
if (n_reg <= 1) begin
is_prime_result <= 1'b0;
done <= 1'b1;
state <= DONE;
end else if (n_reg == 2) begin
is_prime_result <= 1'b1;
done <= 1'b1;
state <= DONE;
end else if (n_reg % 2 == 0) begin
is_prime_result <= 1'b0;
done <= 1'b1;
state <= DONE;
end else begin
state <= COMPUTE_SQRT;
end
end
COMPUTE_SQRT: begin
d_reg <= 3;
state <= ITERATE;
end
ITERATE: begin
done <= 1'b0;
if (d_reg * d_reg > n_reg) begin
is_prime_result <= 1'b1;
done <= 1'b1;
state <= DONE;
end else begin
state <= DIVIDE;
end
end
DIVIDE: begin
done <= 1'b0;
if (n_reg % d_reg == 0) begin
is_prime_result <= 1'b0;
done <= 1'b1;
state <= DONE;
end else begin
d_reg <= d_reg + 2;
state <= ITERATE;
end
end
DONE: begin
if (start) begin
state <= IDLE;
done <= 1'b0;
end else begin
done <= 1'b1;
end
end
default: state <= IDLE;
endcase
end
endmodule