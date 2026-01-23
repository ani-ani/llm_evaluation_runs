module castle_danger_checker(
    input [31:0] n1_x, n1_y,
    input [31:0] n2_x, n2_y,
    input [31:0] n3_x, n3_y,
    input [31:0] n4_x, n4_y,
    input [31:0] c1_x, c1_y,
    input [31:0] c2_x, c2_y,
    input [31:0] c3_x, c3_y,
    input [31:0] c4_x, c4_y,
    output [3:0] danger
);

    // Intermediate results for orientation tests
    // Each castle requires 4 orientation tests against 4 edges
    // Orientation: (B-A) x (P-A) = (Bx-Ax)*(Py-Ay) - (By-Ay)*(Px-Ax)
    // Q16.16 format: (value * 65536)
    // Result will be in 64-bit format to avoid overflow
    // (value * 65536)^2 / 65536 = value^2 * 65536
    // Max 32-bit value is approx 4.29e9. 4.29e9^2 is ~1.84e19, which needs 64 bits.
    // However, for a 16-bit integer part, max value is ~32767. Square is ~1.07e9, fits in 32 bits.
    // But subtraction of two large products might overflow 32 bits.
    // We use 64-bit signed arithmetic for safety.

    // Helper macro for orientation test
    // Returns 1 if positive/negative, 0 if zero or wrong sign
    // We need to determine winding.
    // Since quadrilateral is simple, we can use the even-odd rule or winding number.
    // But simple convex polygon: point inside if all orientations are same sign (or zero).
    // We will calculate orientation signs for all 4 edges for all 4 castles.

    // Wires for orientation results (signs)
    wire signed [63:0] orient_c1_e1, orient_c1_e2, orient_c1_e3, orient_c1_e4;
    wire signed [63:0] orient_c2_e1, orient_c2_e2, orient_c2_e3, orient_c2_e4;
    wire signed [63:0] orient_c3_e1, orient_c3_e2, orient_c3_e3, orient_c3_e4;
    wire signed [63:0] orient_c4_e1, orient_c4_e2, orient_c4_e3, orient_c4_e4;

    // Edge 1: n1 -> n2
    // (n2_x - n1_x) * (c_y - n1_y) - (n2_y - n1_y) * (c_x - n1_x)
    wire signed [63:0] dx_e1 = { {32{n2_x[31]}}, n2_x } - { {32{n1_x[31]}}, n1_x };
    wire signed [63:0] dy_e1 = { {32{n2_y[31]}}, n2_y } - { {32{n1_y[31]}}, n1_y };
    
    // Castle 1 vs Edge 1
    wire signed [63:0] c1_dx_e1 = { {32{c1_x[31]}}, c1_x } - { {32{n1_x[31]}}, n1_x };
    wire signed [63:0] c1_dy_e1 = { {32{c1_y[31]}}, c1_y } - { {32{n1_y[31]}}, n1_y };
    assign orient_c1_e1 = dx_e1 * c1_dy_e1 - dy_e1 * c1_dx_e1;

    // Castle 2 vs Edge 1
    wire signed [63:0] c2_dx_e1 = { {32{c2_x[31]}}, c2_x } - { {32{n1_x[31]}}, n1_x };
    wire signed [63:0] c2_dy_e1 = { {32{c2_y[31]}}, c2_y } - { {32{n1_y[31]}}, n1_y };
    assign orient_c2_e1 = dx_e1 * c2_dy_e1 - dy_e1 * c2_dx_e1;

    // Castle 3 vs Edge 1
    wire signed [63:0] c3_dx_e1 = { {32{c3_x[31]}}, c3_x } - { {32{n1_x[31]}}, n1_x };
    wire signed [63:0] c3_dy_e1 = { {32{c3_y[31]}}, c3_y } - { {32{n1_y[31]}}, n1_y };
    assign orient_c3_e1 = dx_e1 * c3_dy_e1 - dy_e1 * c3_dx_e1;

    // Castle 4 vs Edge 1
    wire signed [63:0] c4_dx_e1 = { {32{c4_x[31]}}, c4_x } - { {32{n1_x[31]}}, n1_x };
    wire signed [63:0] c4_dy_e1 = { {32{c4_y[31]}}, c4_y } - { {32{n1_y[31]}}, n1_y };
    assign orient_c4_e1 = dx_e1 * c4_dy_e1 - dy_e1 * c4_dx_e1;

    // Edge 2: n2 -> n3
    wire signed [63:0] dx_e2 = { {32{n3_x[31]}}, n3_x } - { {32{n2_x[31]}}, n2_x };
    wire signed [63:0] dy_e2 = { {32{n3_y[31]}}, n3_y } - { {32{n2_y[31]}}, n2_y };

    // Castle 1 vs Edge 2
    wire signed [63:0] c1_dx_e2 = { {32{c1_x[31]}}, c1_x } - { {32{n2_x[31]}}, n2_x };
    wire signed [63:0] c1_dy_e2 = { {32{c1_y[31]}}, c1_y } - { {32{n2_y[31]}}, n2_y };
    assign orient_c1_e2 = dx_e2 * c1_dy_e2 - dy_e2 * c1_dx_e2;

    // Castle 2 vs Edge 2
    wire signed [63:0] c2_dx_e2 = { {32{c2_x[31]}}, c2_x } - { {32{n2_x[31]}}, n2_x };
    wire signed [63:0] c2_dy_e2 = { {32{c2_y[31]}}, c2_y } - { {32{n2_y[31]}}, n2_y };
    assign orient_c2_e2 = dx_e2 * c2_dy_e2 - dy_e2 * c2_dx_e2;

    // Castle 3 vs Edge 2
    wire signed [63:0] c3_dx_e2 = { {32{c3_x[31]}}, c3_x } - { {32{n2_x[31]}}, n2_x };
    wire signed [63:0] c3_dy_e2 = { {32{c3_y[31]}}, c3_y } - { {32{n2_y[31]}}, n2_y };
    assign orient_c3_e2 = dx_e2 * c3_dy_e2 - dy_e2 * c3_dx_e2;

    // Castle 4 vs Edge 2
    wire signed [63:0] c4_dx_e2 = { {32{c4_x[31]}}, c4_x } - { {32{n2_x[31]}}, n2_x };
    wire signed [63:0] c4_dy_e2 = { {32{c4_y[31]}}, c4_y } - { {32{n2_y[31]}}, n2_y };
    assign orient_c4_e2 = dx_e2 * c4_dy_e2 - dy_e2 * c4_dx_e2;

    // Edge 3: n3 -> n4
    wire signed [63:0] dx_e3 = { {32{n4_x[31]}}, n4_x } - { {32{n3_x[31]}}, n3_x };
    wire signed [63:0] dy_e3 = { {32{n4_y[31]}}, n4_y } - { {32{n3_y[31]}}, n3_y };

    // Castle 1 vs Edge 3
    wire signed [63:0] c1_dx_e3 = { {32{c1_x[31]}}, c1_x } - { {32{n3_x[31]}}, n3_x };
    wire signed [63:0] c1_dy_e3 = { {32{c1_y[31]}}, c1_y } - { {32{n3_y[31]}}, n3_y };
    assign orient_c1_e3 = dx_e3 * c1_dy_e3 - dy_e3 * c1_dx_e3;

    // Castle 2 vs Edge 3
    wire signed [63:0] c2_dx_e3 = { {32{c2_x[31]}}, c2_x } - { {32{n3_x[31]}}, n3_x };
    wire signed [63:0] c2_dy_e3 = { {32{c2_y[31]}}, c2_y } - { {32{n3_y[31]}}, n3_y };
    assign orient_c2_e3 = dx_e3 * c2_dy_e3 - dy_e3 * c2_dx_e3;

    // Castle 3 vs Edge 3
    wire signed [63:0] c3_dx_e3 = { {32{c3_x[31]}}, c3_x } - { {32{n3_x[31]}}, n3_x };
    wire signed [63:0] c3_dy_e3 = { {32{c3_y[31]}}, c3_y } - { {32{n3_y[31]}}, n3_y };
    assign orient_c3_e3 = dx_e3 * c3_dy_e3 - dy_e3 * c3_dx_e3;

    // Castle 4 vs Edge 3
    wire signed [63:0] c4_dx_e3 = { {32{c4_x[31]}}, c4_x } - { {32{n3_x[31]}}, n3_x };
    wire signed [63:0] c4_dy_e3 = { {32{c4_y[31]}}, c4_y } - { {32{n3_y[31]}}, n3_y };
    assign orient_c4_e3 = dx_e3 * c4_dy_e3 - dy_e3 * c4_dx_e3;

    // Edge 4: n4 -> n1
    wire signed [63:0] dx_e4 = { {32{n1_x[31]}}, n1_x } - { {32{n4_x[31]}}, n4_x };
    wire signed [63:0] dy_e4 = { {32{n1_y[31]}}, n1_y } - { {32{n4_y[31]}}, n4_y };

    // Castle 1 vs Edge 4
    wire signed [63:0] c1_dx_e4 = { {32{c1_x[31]}}, c1_x } - { {32{n4_x[31]}}, n4_x };
    wire signed [63:0] c1_dy_e4 = { {32{c1_y[31]}}, c1_y } - { {32{n4_y[31]}}, n4_y };
    assign orient_c1_e4 = dx_e4 * c1_dy_e4 - dy_e4 * c1_dx_e4;

    // Castle 2 vs Edge 4
    wire signed [63:0] c2_dx_e4 = { {32{c2_x[31]}}, c2_x } - { {32{n4_x[31]}}, n4_x };
    wire signed [63:0] c2_dy_e4 = { {32{c2_y[31]}}, c2_y } - { {32{n4_y[31]}}, n4_y };
    assign orient_c2_e4 = dx_e4 * c2_dy_e4 - dy_e4 * c2_dx_e4;

    // Castle 3 vs Edge 4
    wire signed [63:0] c3_dx_e4 = { {32{c3_x[31]}}, c3_x } - { {32{n4_x[31]}}, n4_x };
    wire signed [63:0] c3_dy_e4 = { {32{c3_y[31]}}, c3_y } - { {32{n4_y[31]}}, n4_y };
    assign orient_c3_e4 = dx_e4 * c3_dy_e4 - dy_e4 * c3_dx_e4;

    // Castle 4 vs Edge 4
    wire signed [63:0] c4_dx_e4 = { {32{c4_x[31]}}, c4_x } - { {32{n4_x[31]}}, n4_x };
    wire signed [63:0] c4_dy_e4 = { {32{c4_y[31]}}, c4_y } - { {32{n4_y[31]}}, n4_y };
    assign orient_c4_e4 = dx_e4 * c4_dy_e4 - dy_e4 * c4_dx_e4;

    // Determine Danger
    // Point is inside/on border if all orientations are >= 0 or all <= 0.
    // However, we don't know the order of points (CW or CCW).
    // If CW, cross products will be <= 0. If CCW, >= 0.
    // We check if all cross products have the same sign (ignoring 0).
    // But wait: "on border" includes 0.
    // So if all are >= 0 OR all are <= 0.
    
    wire c1_pos = (orient_c1_e1 >= 0) && (orient_c1_e2 >= 0) && (orient_c1_e3 >= 0) && (orient_c1_e4 >= 0);
    wire c1_neg = (orient_c1_e1 <= 0) && (orient_c1_e2 <= 0) && (orient_c1_e3 <= 0) && (orient_c1_e4 <= 0);
    assign danger[0] = c1_pos || c1_neg;

    wire c2_pos = (orient_c2_e1 >= 0) && (orient_c2_e2 >= 0) && (orient_c2_e3 >= 0) && (orient_c2_e4 >= 0);
    wire c2_neg = (orient_c2_e1 <= 0) && (orient_c2_e2 <= 0) && (orient_c2_e3 <= 0) && (orient_c2_e4 <= 0);
    assign danger[1] = c2_pos || c2_neg;

    wire c3_pos = (orient_c3_e1 >= 0) && (orient_c3_e2 >= 0) && (orient_c3_e3 >= 0) && (orient_c3_e4 >= 0);
    wire c3_neg = (orient_c3_e1 <= 0) && (orient_c3_e2 <= 0) && (orient_c3_e3 <= 0) && (orient_c3_e4 <= 0);
    assign danger[2] = c3_pos || c3_neg;

    wire c4_pos = (orient_c4_e1 >= 0) && (orient_c4_e2 >= 0) && (orient_c4_e3 >= 0) && (orient_c4_e4 >= 0);
    wire c4_neg = (orient_c4_e1 <= 0) && (orient_c4_e2 <= 0) && (orient_c4_e3 <= 0) && (orient_c4_e4 <= 0);
    assign danger[3] = c4_pos || c4_neg;

endmodule
