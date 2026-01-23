module largest_prime_factor (
input clk,
input rst_n,
input start,
input [15:0] n,
output reg [15:0] result,
output reg done
);

localparam IDLE = 3'd0;
localparam INIT_FACTORS = 3'd1;
localparam CHECK_PRIME = 3'd2;
localparam UPDATE_LARGEST = 3'd3;
localparam DONE_STATE = 3'd4;

function [1:0] is_prime;
input [7:0] d;
begin
if (d < 2) return 1'b0;
if (d == 2) return 1'b1;
if (d % 2 == 0) return 1'b0;
if (3*3 <= d && d %3 ==0) return 1'b0;
if (5*5 <= d && d %5 ==0) return 1'b0;
if (7*7 <= d && d %7 ==0) return 1'b0;
if (9*9 <= d && d %9 ==0) return 1'b0;
if (11*11 <= d && d %11 ==0) return 1'b0;
if (13*13 <= d && d %13 ==0) return 1'b0;
if (15*15 <= d && d %15 ==0) return 1'b0;
return 1'b1;
endfunction

reg [15:0] n_reg;
reg [7:0] divisor;
reg [15:0] largest;
reg [15:0] temp;
reg [2:0] state;
reg is_prime_reg;

always @(posedge clk) begin
if (!rst_n) begin
n_reg <= 16'b0;
divisor <= 8'b2;
largest <= 16'b1;
temp <= 16'b0;
state <= IDLE;
is_prime_reg <= 1'b0;
end else begin
case(state)
IDLE: begin
if (start) state <= INIT_FACTORS;
end
INIT_FACTORS: begin
n_reg <= n;
divisor <= 8'b2;
largest <= 16'b1;
state <= CHECK_PRIME;
end
CHECK_PRIME: begin
is_prime_reg <= is_prime(divisor);
state <= UPDATE_LARGEST;
end
UPDATE_LARGEST: begin
if (divisor * divisor > n_reg || divisor > 255) begin
state <= DONE_STATE;
end else begin
if (is_prime_reg && (n_reg % divisor == 0)) begin
n_reg <= n_reg / divisor;
if (divisor > largest) largest <= divisor;
end
divisor <= divisor + 1;
state <= CHECK_PRIME;
end
end
DONE_STATE: begin
if (n_reg > 1) begin
if (n_reg > largest) largest <= n_reg;
end
result <= largest;
done <= 1'b1;
end
endcase
end
end
endmodule