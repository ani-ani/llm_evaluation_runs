module rarity_solver (
input clk,
input rst_n,
input start,
input [7:0] N,
input [7:0] K,
input [7:0] P,
output reg [7:0] result_char,
output reg valid,
output reg done,
output reg is_possible
);
reg [1:0] state;
reg [7:0] n_reg, k_reg, p_reg;
reg [7:0] string_buf [0:15];
reg [3:0] char_index;
reg [7:0] zero_val;
parameter IDLE = 2'b00;
parameter CHECK = 2'b01;
parameter GENERATE = 2'b10;
always @(*) begin
state <= IDLE;
n_reg <= 8'b0;
k_reg <= 8'b0;
p_reg <= 8'b0;
char_index <= 4'd0;
is_possible <= 1'b0;
done <= 1'b0;
valid <= 1'b0;
result_char <= zero_val;
end
always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
state <= IDLE;
n_reg <= 8'b0;
k_reg <= 8'b0;
p_reg <= 8'b0;
char_index <= 4'd0;
is_possible <= 1'b0;
done <= 1'b0;
valid <= 1'b0;
result_char <= 8'b0;
end else begin
case (state)
IDLE: begin
if (start) begin
n_reg <= N;
k_reg <= K;
p_reg <= P;
state <= CHECK;
end
end
CHECK: begin
wire feasible = 1'b1;
if (p_reg > n_reg) feasible = 1'b0;
else if (k_reg > n_reg) feasible = 1'b0;
else if (k_reg == 1) begin
if (p_reg != n_reg) feasible = 1'b0;
end
else if (p_reg < n_reg) begin
if (k_reg < 2) feasible = 1'b0;
end
else if (k_reg == 2 && p_reg == 2 && n_reg > 4) feasible = 1'b0;
if (feasible) begin
generate_string(n_reg, k_reg, p_reg, string_buf);
is_possible <= 1'b1;
done <= 1'b0;
char_index <= 4'd0;
state <= GENERATE;
end else begin
is_possible <= 1'b0;
done <= 1'b1;
end
end
GENERATE: begin
if (char_index < n_reg) begin
result_char <= string_buf[char_index];
valid <= 1'b1;
char_index <= char_index + 1;
end else begin
result_char <= 8'b0;
valid <= 1'b0;
done <= 1'b1;
state <= IDLE;
end
end
endcase
end
end
function [7:0] generate_string [0:15] (input integer n, input integer k, input integer p);
integer i, j, suffix_i, block_size, num_blocks, remaining;
block_size = p;
num_blocks = n / (2 * block_size);
remaining = n - num_blocks * 2 * block_size;
for (i=0; i < n; i++) begin
if (p == n) begin
if (i < n - i -1) begin
generate_string[i] = 97 + (i % k);
end else if (i == n - i -1) begin
generate_string[i] = 97 + (i % k);
end else begin
generate_string[i] = generate_string[n-1 -i];
end
end else if (k >=3) begin
if (i < p) begin
if (i < p - i -1) begin
generate_string[i] = 97 + (i % k);
end else if (i == p - i -1) begin
generate_string[i] = 97 + (i % k);
end else begin
generate_string[i] = generate_string[p-1 -i];
end
end else begin
generate_string[i] = 97 + (i - p) % 3;
end
end else if (k ==2 && p >=3) begin
if (i < num_blocks * 2 * block_size) begin
if (i < num_blocks * block_size) begin
generate_string[i] = 97 + 0;
end else begin
generate_string[i] = 97 + 1;
end
end else begin
if (i - num_blocks * 2 * block_size < block_size) begin
generate_string[i] = 97 + 0;
end else begin
generate_string[i] = 97 + 1;
end
end
end else if (k ==2 && p ==2 && n <=4) begin
generate_string[i] = (i < n-1) ? 97 : 98;
end
end
endfunction
endmodule