module train_chaos (
input clk,
input rst_n,
input start,
input [2:0] p_in,
input [2:0] idx_in,
output reg [15:0] max_chaos,
output reg done 
);

reg [23:0] passenger_reg;
reg [23:0] order_reg;
reg [15:0] max_chaos_reg;
reg [2:0] k_counter;
reg [2:0] load_pass_counter;
reg [2:0] load_order_counter;
reg [2:0] state_reg;

localparam IDLE = 3'd0,
LOAD_PASSENGERS = 3'd1,
LOAD_ORDER = 3'd2,
PROCESSING_K = 3'd3,
DONE = 3'd4;

reg [2:0] next_state;

always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
passenger_reg <= 24'b0;
order_reg <= 24'b0;
max_chaos_reg <= 16'b0;
k_counter <= 3'b0;
load_pass_counter <= 3'b0;
load_order_counter <= 3'b0;
state_reg <= IDLE;
next_state <= IDLE;
done <= 1'b0;
end else begin
next_state <= state_reg;

case (state_reg)
IDLE: begin
if (start) begin
load_pass_counter <= 3'b0;
next_state = LOAD_PASSENGERS;
end else begin
next_state = IDLE;
end
end
LOAD_PASSENGERS: begin
if (load_pass_counter < 8) begin
passenger_reg[load_pass_counter*3 + 2 : load_pass_counter*3] <= p_in;
load_pass_counter <= load_pass_counter + 1;
next_state = LOAD_PASSENGERS;
end else begin
load_pass_counter <= 3'b0;
load_order_counter <= 3'b0;
next_state = LOAD_ORDER;
end
end
LOAD_ORDER: begin
if (load_order_counter < 8) begin
order_reg[load_order_counter*3 + 2 : load_order_counter*3] <= idx_in;
load_order_counter <= load_order_counter + 1;
next_state = LOAD_ORDER;
end else begin
k_counter <= 3'b0;
next_state = PROCESSING_K;
end
end
PROCESSING_K: begin
if (k_counter < 8) begin
k_counter <= k_counter + 1;
next_state = PROCESSING_K;
end else begin
next_state = DONE;
end
end
DONE: begin
next_state = DONE;
done <= 1'b1;
end
default: next_state = IDLE;
endcase
state_reg <= next_state;
end
endmodule