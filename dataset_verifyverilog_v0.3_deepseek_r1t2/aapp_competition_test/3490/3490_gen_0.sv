module crash_detection (
    input signed [31:0] x1, y1, r1,
    input signed [31:0] x2, y2, r2,
    output wire crash
);
    // Q16.16 fixed-point format
    localparam signed [31:0] PI = 32'sd205887;
    localparam signed [31:0] TWO_PI = 32'sd411774;
    localparam signed [31:0] PI_OVER_2 = 32'sd102943;

    // Distance calculation
    wire signed [31:0] dx = x1 - x2;
    wire signed [31:0] dy = y1 - y2;
    wire signed [63:0] dx_sq = dx * dx;
    wire signed [63:0] dy_sq = dy * dy;
    wire signed [63:0] distance_squared = dx_sq + dy_sq;
    
    // Radius threshold
    wire signed [31:0] r_sum = r1 + r2;
    wire signed [63:0] r_sum_sq = r_sum * r_sum;
    
    // Angle calculation
    wire signed [31:0] r_diff = (r1 > r2) ? (r1 - r2) : (r2 - r1);
    wire signed [31:0] angle_diff_wrapped = (r_diff > PI) ? (TWO_PI - r_diff) : r_diff;
    
    // Condition checks
    wire distance_ok = (distance_squared < r_sum_sq);
    wire angle_ok = (angle_diff_wrapped > PI_OVER_2);
    assign crash = distance_ok && angle_ok;
endmodule