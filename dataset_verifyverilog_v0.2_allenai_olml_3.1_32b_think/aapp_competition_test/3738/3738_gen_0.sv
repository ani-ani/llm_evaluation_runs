module robot_path_solver (
input clk,
input rst_n,
input start,
input [7:0] signed target_a,
input [7:0] signed target_b,
input [3:0] cmd_addr,
input [7:0] cmd_char,
output reg found,
output reg done
);
reg [3:0] state_reg;
reg [7:0] command [7:0];
reg [2:0] cmd_load_counter;
reg signed [7:0] curr_x, curr_y;
reg [1:0] rep_count;
reg [2:0] command_idx;
reg [3:0] next_state;
localparam IDLE = 4'd0;
localparam LOAD_CMD = 4'd1;
localparam PROCESS = 4'd2;
localparam CHECK = 4'd3;
localparam FINISH = 4'd4;
always @(*) begin
state_reg = IDLE;
command = 8'b0;
cmd_load_counter = 3'b0;
curr_x = 8'b0;
curr_y = 8'b0;
rep_count = 2'b0;
command_idx = 3'b0;
next_state = IDLE;
found = 1'b0;
done = 1'b0;
end
always @(posedge clk) begin
if (!rst_n) begin
state_reg <= IDLE;
command <= 8'b0;
cmd_load_counter <= 3'b0;
curr_x <= 8'b0;
curr_y <= 8'b0;
rep_count <= 2'b0;
command_idx <= 3'b0;
found <= 1'b0;
done <= 1'b0;
next_state <= IDLE;
end else begin
case(state_reg)
IDLE: begin
if (start) begin
next_state <= LOAD_CMD;
end else begin
next_state <= IDLE;
end
end
LOAD_CMD: begin
if (cmd_load_counter < 8) begin
command[cmd_load_counter] <= cmd_char;
cmd_load_counter <= cmd_load_counter + 1;
next_state <= LOAD_CMD;
end else begin
next_state <= PROCESS;
curr_x <= 8'b0;
curr_y <= 8'b0;
rep_count <= 2'b0;
command_idx <= 3'b0;
end
end
PROCESS: begin
integer movement_x = 0, movement_y = 0;
case(command[command_idx])
8'h55: movement_y = 1;
8'h44: movement_y = -1;
8'h52: movement_x = 1;
8'h4C: movement_x = -1;
default: movement_x=0; movement_y=0;
endcase
curr_x <= curr_x + movement_x;
curr_y <= curr_y + movement_y;
if (curr_x == target_a && curr_y == target_b) begin
found <= 1'b1;
next_state <= FINISH;
end else begin
if (command_idx == 7) begin
command_idx <= 3'b0;
rep_count <= rep_count + 1;
if (rep_count == 2) begin
next_state <= CHECK;
end else begin
next_state <= PROCESS;
end
end else begin
command_idx <= command_idx + 1;
next_state <= PROCESS;
end
end
end
CHECK: begin
if (curr_x == target_a && curr_y == target_b) begin
found <= 1'b1;
end
next_state <= FINISH;
end
FINISH: begin
done <= 1'b1;
next_state <= IDLE;
end
endcase
state_reg <= next_state;
end
end
endmodule
