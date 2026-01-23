module conveyor_path_finder (input [31:0] ax_q16, ay_q16, input [31:0] bx_q16, by_q16, input [31:0] cx_q16, cy_q16, input [31:0] dx_q16, dy_q16, output reg [31:0] min_time_q16);

function [31:0] sqrt_approx;
    input [63:0] X;
    sqrt_approx = X >> 2;
endfunction

// Distance AB
wire [63:0] dx_ab, dy_ab;
wire [63:0] dx_ab_sq, dy_ab_sq, sum_ab;
wire [31:0] dist_ab;
assign dx_ab = bx_q16 - ax_q16;
assign dy_ab = by_q16 - ay_q16;
assign dx_ab_sq = dx_ab * dx_ab;
assign dy_ab_sq = dy_ab * dy_ab;
assign sum_ab = dx_ab_sq + dy_ab_sq;
assign dist_ab = sqrt_approx(sum_ab);

// Distance AC
wire [63:0] dx_ac, dy_ac;
wire [63:0] dx_ac_sq, dy_ac_sq, sum_ac;
wire [31:0] dist_ac;
assign dx_ac = cx_q16 - ax_q16;
assign dy_ac = cy_q16 - ay_q16;
assign dx_ac_sq = dx_ac * dx_ac;
assign dy_ac_sq = dy_ac * dy_ac;
assign sum_ac = dx_ac_sq + dy_ac_sq;
assign dist_ac = sqrt_approx(sum_ac);

// Distance CD
wire [63:0] dx_cd, dy_cd;
wire [63:0] dx_cd_sq, dy_cd_sq, sum_cd;
wire [31:0] dist_cd;
assign dx_cd = dx_q16 - cx_q16;
assign dy_cd = dy_q16 - cy_q16;
assign dx_cd_sq = dx_cd * dx_cd;
assign dy_cd_sq = dy_cd * dy_cd;
assign sum_cd = dx_cd_sq + dy_cd_sq;
assign dist_cd = sqrt_approx(sum_cd);

// Distance DB
wire [63:0] dx_db, dy_db;
wire [63:0] dx_db_sq, dy_db_sq, sum_db;
wire [31:0] dist_db;
assign dx_db = bx_q16 - dx_q16;
assign dy_db = by_q16 - dy_q16;
assign dx_db_sq = dx_db * dx_db;
assign dy_db_sq = dy_db * dy_db;
assign sum_db = dx_db_sq + dy_db_sq;
assign dist_db = sqrt_approx(sum_db);

// Calculate times
wire [31:0] time_direct = dist_ab;
wire [31:0] time_conveyor = dist_ac + (dist_cd >> 1) + dist_db;
wire [31:0] min_time_val;
assign min_time_val = (time_direct < time_conveyor) ? time_direct : time_conveyor;
assign min_time_q16 = min_time_val;

endmodule