module sum_collatz (
input clk,
input rst_n, // active low
input start,
input [15:0] L,
input [15:0] R,
output reg [31:0] sum,
output reg done
);

localparam IDLE = 2'd0;
localparam CALC_F = 2'd1;
localparam ACCUM = 2'd2;
localparam INCREMENT_X = 2'd3;
localparam DONE = 2'd4;

reg [2:0] state;
reg [15:0] current_X;
reg [31:0] sum_reg;
reg [31:0] iterations_count;
reg [16:0] temp_X;

reg [2:0] state_next;
reg [15:0] current_X_next;
reg [31:0] sum_next;
reg [31:0] iterations_count_next;
reg [16:0] temp_X_next;

always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
state <= IDLE;
current_X <= 16'd0;
sum_reg <= 32'd0;
iterations_count <= 32'd0;
temp_X <= 17'd0;
end else begin
state_next = state;
current_X_next = current_X;
sum_next = sum_reg;
iterations_count_next = iterations_count;
temp_X_next = temp_X;

case (state)
IDLE: begin
if (start) begin
state_next = CALC_F;
current_X_next = L;
end
end
CALC_F: begin
if (temp_X == 17'd0) begin
temp_X_next = current_X;
state_next = CALC_F;
end else begin
if (temp_X == 1) begin
state_next = ACCUM;
end else begin
if (temp_X % 2 == 0) begin
temp_X_next = temp_X >> 1;
end else begin
temp_X_next = temp_X + 1;
end
iterations_count_next = iterations_count + 1;
state_next = CALC_F;
end
end
end
ACCUM: begin
sum_next = sum_reg + iterations_count;
state_next = INCREMENT_X;
end
INCREMENT_X: begin
current_X_next = current_X + 1;
if (current_X_next > R) begin
state_next = DONE;
end else begin
state_next = CALC_F;
end
end
DONE: begin
// No action
end
endcase

state <= state_next;
current_X <= current_X_next;
sum_reg <= sum_next;
iterations_count <= iterations_count_next;
temp_X <= temp_X_next;
end
endmodule

assign sum = sum_reg;
assign done = (state == DONE);