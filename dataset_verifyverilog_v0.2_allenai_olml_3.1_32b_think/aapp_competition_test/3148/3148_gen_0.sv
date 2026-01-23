module lifeguard_divider (
input clk,
input rst_n,
input start,
input [31:0] num_swimmers,
input [31:0] swimmer_x [0:7],
input [31:0] swimmer_y [0:7],
output reg [31:0] lifeguard1_x,
output reg [31:0] lifeguard1_y,
output reg [31:0] lifeguard2_x,
output reg [31:0] lifeguard2_y,
output reg done,
output reg valid
);

reg [31:0] state;
reg [31:0] search_count;
reg [31:0] lg1_x, lg1_y, lg2_x, lg2_y;
reg [31:0] found_lg1_x, found_lg1_y, found_lg2_x, found_lg2_y;
reg solution_found;
reg [2:0] swimmer_idx;
reg [31:0] count1, count2, equidistant;
reg [31:0] num_swimmers_reg;
reg [31:0] swimmer_x_reg [0:7];
reg [31:0] swimmer_y_reg [0:7];
reg [31:0] candidate_count;

parameter IDLE = 3'd0;
parameter SEARCH = 3'd1;
parameter VERIFY = 3'd2;
parameter DONE = 3'd3;
localparam INT21 = 21;
localparam MAX_COUNT = 1023;

always_ff @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
search_count <= 32'd0;
solution_found <= 1'b0;
done <= 1'b0;
valid <= 1'b0;
lifeguard1_x <= 32'd0;
lifeguard1_y <= 32'd0;
lifeguard2_x <= 32'd0;
lifeguard2_y <= 32'd0;
num_swimmers_reg <= num_swimmers;
swimmer_x_reg[0] <= swimmer_x[0];
swimmer_x_reg[1] <= swimmer_x[1];
swimmer_x_reg[2] <= swimmer_x[2];
swimmer_x_reg[3] <= swimmer_x[3];
swimmer_x_reg[4] <= swimmer_x[4];
swimmer_x_reg[5] <= swimmer_x[5];
swimmer_x_reg[6] <= swimmer_x[6];
swimmer_x_reg[7] <= swimmer_x[7];
swimmer_y_reg[0] <= swimmer_y[0];
swimmer_y_reg[1] <= swimmer_y[1];
swimmer_y_reg[2] <= swimmer_y[2];
swimmer_y_reg[3] <= swimmer_y[3];
swimmer_y_reg[4] <= swimmer_y[4];
swimmer_y_reg[5] <= swimmer_y[5];
swimmer_y_reg[6] <= swimmer_y[6];
swimmer_y_reg[7] <= swimmer_y[7];
end else if (state == IDLE) begin
if (start) begin
state <= SEARCH;
candidate_count <= 32'd0;
swimmer_idx <= 32'd0;
count1 <= 32'd0;
count2 <= 32'd0;
equidistant <= 32'd0;
end
end else if (state == SEARCH) begin
if (candidate_count <= MAX_COUNT) begin
lg1_x = -1000 + ((candidate_count % INT21)) * 100;
lg1_y = -1000 + ((candidate_count / INT21) % INT21) * 100;
lg2_x = -1000 + ((candidate_count / (INT21*INT21)) % INT21) * 100;
lg2_y = -1000 + ((candidate_count / (INT21*INT21*INT21)) % INT21) * 100;
state <= VERIFY;
end else begin
state <= DONE;
solution_found <= 1'b0;
end
end else if (state == VERIFY) begin
if (swimmer_idx < num_swimmers_reg) begin
reg [31:0] sx = swimmer_x_reg[swimmer_idx];
reg [31:0] sy = swimmer_y_reg[swimmer_idx];
reg [31:0] dx1 = sx - lg1_x;
reg [31:0] dy1 = sy - lg1_y;
reg [31:0] dist1_sq = dx1*dx1 + dy1*dy1;
reg [31:0] dx2 = sx - lg2_x;
reg [31:0] dy2 = sy - lg2_y;
reg [31:0] dist2_sq = dx2*dx2 + dy2*dy2;
if (dist1_sq < dist2_sq) begin
count1 <= count1 +1;
end else if (dist1_sq > dist2_sq) begin
count2 <= count2 +1;
end else begin
equidistant <= equidistant +1;
end
swimmer_idx <= swimmer_idx +1;
end else begin
if (equidistant <=1) begin
if (count1 == count2 || ((count1 == count2 +1 && equidistant ==1) || (count2 == count1 +1 && equidistant ==1))) begin
found_lg1_x <= lg1_x;
found_lg1_y <= lg1_y;
found_lg2_x <= lg2_x;
found_lg2_y <= lg2_y;
solution_found <= 1'b1;
end
end
state <= DONE;
end
end else if (state == DONE) begin
if (solution_found) begin
valid <= 1'b1;
end else begin
valid <= 1'b0;
end
done <= 1'b1;
lifeguard1_x <= solution_found ? found_lg1_x : 32'd0;
lifeguard1_y <= solution_found ? found_lg1_y : 32'd0;
lifeguard2_x <= solution_found ? found_lg2_x : 32'd0;
lifeguard2_y <= solution_found ? found_lg2_y : 32'd0;
end
end

assign lifeguard1_x = (state == DONE) ? (solution_found ? found_lg1_x : 32'd0) : 32'd0;
assign lifeguard1_y = (state == DONE) ? (solution_found ? found_lg1_y : 32'd0) : 32'd0;
assign lifeguard2_x = (state == DONE) ? (solution_found ? found_lg2_x : 32'd0) : 32'd0;
assign lifeguard2_y = (state == DONE) ? (solution_found ? found_lg2_y : 32'd0) : 32'd0;
assign done = state == DONE;
assign valid = (state == DONE) ? solution_found : 1'b0;
endmodule