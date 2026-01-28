module circumsphere (
    input wire signed [7:0] p0_x, p0_y, p0_z,
    input wire signed [7:0] p1_x, p1_y, p1_z,
    input wire signed [7:0] p2_x, p2_y, p2_z,
    input wire signed [7:0] p3_x, p3_y, p3_z,
    output reg signed [31:0] x_c, y_c, z_c
);
    // Convert inputs to real for computation
    real a0, a1, a2;
    real b0, b1, b2;
    real c0, c1, c2;
    real d0, d1, d2;

    always @(*) begin
        a0 = p0_x; a1 = p0_y; a2 = p0_z;
        b0 = p1_x; b1 = p1_y; b2 = p1_z;
        c0 = p2_x; c1 = p2_y; c2 = p2_z;
        d0 = p3_x; d1 = p3_y; d2 = p3_z;
    end

    // Computation of circumsphere center
    real u0, u1, u2;
    real v0, v1, v2;
    real w0, w1, w2;

    real dot_u, dot_v, dot_w;
    real cross_vw0, cross_vw1, cross_vw2;
    real cross_wu0, cross_wu1, cross_wu2;
    real cross_uv0, cross_uv1, cross_uv2;

    real num0, num1, num2;
    real denom;
    real X0, X1, X2;
    real xc, yc, zc;

    always @(*) begin
        // Differences
        u0 = b0 - a0; u1 = b1 - a1; u2 = b2 - a2;
        v0 = c0 - a0; v1 = c1 - a1; v2 = c2 - a2;
        w0 = d0 - a0; w1 = d1 - a1; w2 = d2 - a2;

        // Dot products
        dot_u = u0*u0 + u1*u1 + u2*u2;
        dot_v = v0*v0 + v1*v1 + v2*v2;
        dot_w = w0*w0 + w1*w1 + w2*w2;

        // Cross products
        cross_vw0 = v1*w2 - v2*w1;
        cross_vw1 = v2*w0 - v0*w2;
        cross_vw2 = v0*w1 - v1*w0;

        cross_wu0 = w1*u2 - w2*u1;
        cross_wu1 = w2*u0 - w0*u2;
        cross_wu2 = w0*u1 - w1*u0;

        cross_uv0 = u1*v2 - u2*v1;
        cross_uv1 = u2*v0 - u0*v2;
        cross_uv2 = u0*v1 - u1*v0;

        // Numerator components
        num0 = dot_u*cross_vw0 + dot_v*cross_wu0 + dot_w*cross_uv0;
        num1 = dot_u*cross_vw1 + dot_v*cross_wu1 + dot_w*cross_uv1;
        num2 = dot_u*cross_vw2 + dot_v*cross_wu2 + dot_w*cross_uv2;

        // Denominator: 2 * (u · (v × w))
        denom = 2 * (u0*cross_vw0 + u1*cross_vw1 + u2*cross_vw2);

        // X = numerator / denominator
        X0 = num0 / denom;
        X1 = num1 / denom;
        X2 = num2 / denom;

        // Center = P0 + X
        xc = a0 + X0;
        yc = a1 + X1;
        zc = a2 + X2;
    end

    // Convert to Q16.16 fixed-point (16 fractional bits)
    always @(*) begin
        x_c = $rtoi(xc * 65536.0);
        y_c = $rtoi(yc * 65536.0);
        z_c = $rtoi(zc * 65536.0);
    end

endmodule