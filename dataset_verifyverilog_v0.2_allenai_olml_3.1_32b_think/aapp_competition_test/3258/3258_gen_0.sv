module cat_chase_verifier (input [3:0] valid_mice_mask, input [4:0][31:0] x_coords, input [4:0][31:0] y_coords, input [4:0][31:0] deadlines, input [4:0][31:0] velocities, output reg success);
always @(*) begin
int i, step_count;
signed [31:0] current_x, current_y, dx, dy, dx_abs, dy_abs, distance, current_time, time_step;
success = 1;
current_x = 0;
current_y = 0;
current_time = 0;
step_count = 0;
for (i=0; i<4; i++) begin
if (valid_mice_mask & (1<<i)) begin
step_count = step_count + 1;
if (step_count > 4) begin
success = 0;
end else begin
signed [31:0] target_x = x_coords[i];
signed [31:0] target_y = y_coords[i];
signed [31:0] deadline = deadlines[i];
signed [31:0] velocity = velocities[step_count - 1];
dx = target_x - current_x;
dy = target_y - current_y;
dx_abs = (dx ^ (dx >> 31)) - (dx >> 31);
dy_abs = (dy ^ (dy >> 31)) - (dy >> 31);
distance = dx_abs + dy_abs;
time_step = (distance * 65536) / velocity;
current_time = current_time + time_step;
if (current_time > deadline) begin
success = 0;
end
current_x = target_x;
current_y = target_y;
end
end
end
end
endmodule