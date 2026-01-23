module find_zero (input clk,input rst_n,input start,input [4:0] degree,input [3:0][15:0] coeffs,output reg [15:0] result,output reg done,output reg error);

// State machine signals
reg [2:0] state, next_state;
reg [31:0] x;
reg [31:0] f, f_prime;
reg [15:0] iteration;
reg [31:0] result_reg;
reg done_reg, error_reg;

// States
parameter IDLE = 3'd0;
parameter EVAL_F = 3'd1;
parameter EVAL_FP = 3'd2;
parameter COMPUTE_DELTA = 3'd3;
parameter UPDATE_X = 3'd4;
parameter DONE_STATE = 3'd5;
parameter ERROR_STATE = 3'd6;

always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
x <= 0;
f <= 0;
f_prime <=0;
iteration <=0;
done_reg <=0;
error_reg <=0;
result_reg <=0;
end else begin
state <= next_state;

case (state)
IDLE: begin
if (start) begin
next_state = EVAL_F;
x <= 0;
iteration <=0;
end else begin
next_state = IDLE;
end
end
EVAL_F: begin
f <= 0; // Placeholder
next_state = EVAL_FP;
end
EVAL_FP: begin
f_prime <=0; // Placeholder
next_state = COMPUTE_DELTA;
end
COMPUTE_DELTA: begin
if (f_prime ==0) begin
error_reg <=1;
next_state = ERROR_STATE;
end else begin
reg [31:0] delta;
delta = - (f >> 8) / f_prime;
if (delta < -0x8000) delta = -0x8000;
else if (delta > 0x7FFF) delta = 0x7FFF;
next_state = UPDATE_X;
end
end
UPDATE_X: begin
reg [31:0] x_new;
x_new = x + delta;
if (x_new < -0x8000) x_new = -0x8000;
else if (x_new > 0x7FFF) x_new = 0x7FFF;
x <= x_new;
iteration <= iteration +1;
if (iteration <16) begin
next_state = EVAL_F;
end else begin
error_reg <=1;
next_state = ERROR_STATE;
end
end
DONE_STATE: begin
done_reg <=1;
result_reg <= x;
next_state = DONE_STATE;
end
ERROR_STATE: begin
error_reg <=1;
next_state = ERROR_STATE;
end
endcase
end
end

assign result = result_reg[15:0];
assign done = done_reg;
assign error = error_reg;
endmodule