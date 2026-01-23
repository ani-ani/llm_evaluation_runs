module right_angle_triangle(
    input [7:0] a,
    input [7:0] b,
    input [7:0] c,
    output reg result)
wire [7:0] max_side;
wire [7:0] mid_side;
wire [7:0] min_side;
wire [7:0] ab_max, ab_min;
wire [7:0] tmp_max, tmp_min;
wire [15:0] min_sq;
wire [15:0] mid_sq;
wire [15:0] max_sq;
wire [15:0] sum_squares;

assign ab_max = (a > b) ? a : b;
assign ab_min = (a > b) ? b : a;

assign tmp_max = (ab_max > c) ? ab_max : c;
assign tmp_min = (ab_max > c) ? c : ab_max;

assign max_side = tmp_max;
assign mid_side = (tmp_min > ab_min) ? tmp_min : ab_min;
assign min_side = (tmp_min > ab_min) ? ab_min : tmp_min;

assign min_sq = min_side * min_side;
assign mid_sq = mid_side * mid_side;
assign max_sq = max_side * max_side;
assign sum_squares = min_sq + mid_sq;

always @(*) begin
    if (sum_squares == max_sq && max_side > 0) begin
        result = 1'b1;
    end else begin
        result = 1'b0;
    end
end

endmodule