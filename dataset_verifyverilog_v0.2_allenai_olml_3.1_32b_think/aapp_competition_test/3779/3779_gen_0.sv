module martian_tax_solver (
input clk,
input rst_n, // active low
input start,
input [2:0] n,
input [4:0] k,
input [29:0] a,
output reg [4:0] result_d,
output reg [2:0] result_index,
output reg valid,
output reg done
);

// Internal registers (excluding outputs)
reg [2:0] state_reg;
reg [2:0] denom_idx_reg;
reg [31:0] current_g_reg;
reg [31:0] g_reg;
reg [31:0] G_reg;
reg [4:0] m_counter_reg;

// GCD function
function [31:0] gcd;
input [31:0] x, y;
reg [31:0] a, b;
integer i;
if (y == 0) return x;
a = x;
b = y;
while (b != 0) begin
a = b;
b = a % b;
end
return a;
endfunction

always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
// Reset all registers
state_reg <= 0; // IDLE
denom_idx_reg <=0;
current_g_reg <=0;
g_reg <=0;
G_reg <=0;
m_counter_reg <=0;
done <=0;
valid <=0;
end else begin
case(state_reg)
IDLE: begin
if (start) begin
state_reg <= 1; // GCD_CALC
denom_idx_reg <=0;
current_g_reg <=0;
end
end
GCD_CALC: begin
// Extract current denomination
reg [5:0] a_i;
a_i = a[(denom_idx_reg*6 +5) : denom_idx_reg*6];
// Compute temp_i = GCD(a_i, k)
integer temp_i;
temp_i = gcd(a_i, k);
// Update current_g
current_g_reg <= gcd(current_g_reg, temp_i);
// Move to next denomination or compute G
if (denom_idx_reg < n) begin
denom_idx_reg <= denom_idx_reg +1;
state_reg <=1; // stay in GCD_CALC
end else begin
// All denominations processed
g_reg <= current_g_reg;
G_reg <= gcd(g_reg, k);
// Move to RESULT_GEN
state_reg <=2; // RESULT_GEN
denom_idx_reg <=0; // reset
end
end
RESULT_GEN: begin
integer k_int, max_m;
k_int = k;
if (G_reg ==0) begin
max_m =0;
end else begin
max_m = k_int / G_reg;
end
if (m_counter_reg < max_m) begin
result_d <= m_counter_reg * G_reg;
result_index <= m_counter_reg;
valid <=1;
m_counter_reg <= m_counter_reg +1;
state_reg <=2; // stay in RESULT_GEN
end else begin
// All results sent
valid <=0;
done <=1;
state_reg <=3; // DONE
m_counter_reg <=0;
end
end
DONE: begin
// Stay in DONE
state_reg <=3;
end
default: state_reg <=0;
endcase
end
endmodule