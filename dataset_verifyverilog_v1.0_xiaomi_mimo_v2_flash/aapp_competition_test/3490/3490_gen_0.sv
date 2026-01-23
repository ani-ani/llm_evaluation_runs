module crash_detection (
    input signed [31:0] x1, y1, r1,
    input signed [31:0] x2, y2, r2,
    output crash
);
    // Fixed-point: Q16.16 format (16 integer bits, 16 fractional bits)
    // All inputs are signed fixed-point numbers
    
    wire signed [31:0] dx = x1 - x2;
    wire signed [31:0] dy = y1 - y2;
    
    // Compute squared distance (requires 64-bit to avoid overflow)
    wire signed [63:0] d2 = dx[31] ? -dx * dx : dx * dx;
    wire signed [63:0] d2_y = dy[31] ? -dy * dy : dy * dy;
    wire signed [63:0] distance_squared = d2 + d2_y;
    
    // Compute absolute angle difference
    wire signed [31:0] angle_diff = (r1 > r2) ? (r1 - r2) : (r2 - r1);
    wire signed [31:0] angle_diff_wrapped = (angle_diff > 32'sd412316860416) ? (32'sd824633720832 - angle_diff) : angle_diff;
    
    // Precompute constants in Q16.16
    wire signed [31:0] threshold_distance = 32'sd262144;  // 4.0 in Q16.16 (2^2 = 4)
    wire signed [31:0] quarter_turn = 32'sd1030792151;   // π/2 in Q16.16
    
    // Check conditions
    wire distance_ok = (distance_squared < {threshold_distance, 16'd0});
    wire angle_ok = (angle_diff_wrapped > quarter_turn);
    
    assign crash = distance_ok && angle_ok;

endmodule