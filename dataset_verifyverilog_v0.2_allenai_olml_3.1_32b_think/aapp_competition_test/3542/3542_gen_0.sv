module grid_router (
input clk,
input rst_n,
input start,
input [3:0] grid_n, grid_m,
input [3:0] a1_x, a1_y, a2_x, a2_y, b1_x, b1_y, b2_x, b2_y,
output reg [7:0] result,
output reg done
);

localparam IDLE = 3'd0,
CALC_DIST = 3'd1,
CHECK_INTERSECTION = 3'd2,
COMPUTE_RESULT = 3'd3,
DONE = 3'd4;

reg [2:0] state,
reg [1:0] compute_counter,
output reg [7:0] result,
output reg done,
reg [1:0] valid;
reg [3:0] dist_ax, dist_ay, dist_bx, dist_by;
reg [7:0] dist_a, dist_b;
reg [3:0] a_min_x, a_max_x, a_min_y, a_max_y,
b_min_x, b_max_x, b_min_y, b_max_y;
reg no_overlap;
reg [7:0] result_value;

always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
compute_counter <= 2'd0;
result <= 8'd0;
done <= 1'b0;
end else begin
case (state)
IDLE: begin
if (start) begin
state <= CALC_DIST;
end else begin
state <= IDLE;
end
CALC_DIST: begin
state <= CHECK_INTERSECTION;
end
CHECK_INTERSECTION: begin
state <= COMPUTE_RESULT;
compute_counter <= 3'd3;
end
COMPUTE_RESULT: begin
valid = 1'b1;
if (a1_x < 0 || a1_x >= grid_n) valid = 1'b0;
if (a1_y < 0 || a1_y >= grid_m) valid = 1'b0;
if (a2_x < 0 || a2_x >= grid_n) valid = 1'b0;
if (a2_y < 0 || a2_y >= grid_m) valid = 1'b0;
if (b1_x < 0 || b1_x >= grid_n) valid = 1'b0;
if (b1_y < 0 || b1_y >= grid_m) valid = 1'b0;
if (b2_x < 0 || b2_x >= grid_n) valid = 1'b0;
if (b2_y < 0 || b2_y >= grid_m) valid = 1'b0;

 dist_ax = (a1_x > a2_x) ? a1_x - a2_x : a2_x - a1_x;
 dist_ay = (a1_y > a2_y) ? a1_y - a2_y : a2_y - a1_y;
 dist_a = dist_ax + dist_ay;
 dist_bx = (b1_x > b2_x) ? b1_x - b2_x : b2_x - b1_x;
 dist_by = (b1_y > b2_y) ? b1_y - b2_y : b2_y - b1_y;
 dist_b = dist_bx + dist_by;

 a_min_x = (a1_x < a2_x) ? a1_x : a2_x;
 a_max_x = (a1_x > a2_x) ? a1_x : a2_x;
 a_min_y = (a1_y < a2_y) ? a1_y : a2_y;
 a_max_y = (a1_y > a2_y) ? a1_y : a2_y;

 b_min_x = (b1_x < b2_x) ? b1_x : b2_x;
 b_max_x = (b1_x > b2_x) ? b1_x : b2_x;
 b_min_y = (b1_y < b2_y) ? b1_y : b2_y;
 b_max_y = (b1_y > b2_y) ? b1_y : f2_y;

 no_overlap = (a_max_x < b_min_x) || (b_max_x < a_min_x) ||
 (a_max_y < b_min_y) || (b_max_y < a_min_y);

 if (!valid) begin
 result_value = 8'd255;
 end else if (no_overlap) begin
 result_value = dist_a + dist_b;
 end else begin
 result_value = 8'd255;
 end

 if (compute_counter == 0) begin
 result <= result_value;
 done <= 1'b1;
 state <= DONE;
 compute_counter <= 0;
 end else begin
 state <= COMPUTE_RESULT;
 compute_counter <= compute_counter - 1;
 done <= 1'b0;
 end
end // COMPUTE_RESULT

DONE: state <= DONE;
default: state <= IDLE;
endcase
end // else
end // always
endmodule