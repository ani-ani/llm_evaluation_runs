module laser_reflection_calculator(
    input  [31:0] x1,
    input  [31:0] y1,
    input  [31:0] x2,
    input  [31:0] y2,
    input  [31:0] px,
    input  [31:0] py,
    output reg        valid_hit,
    output reg        inf_low,
    output reg        inf_high,
    output reg [31:0] y_low,
    output reg [31:0] y_high
);

    // Treat inputs as signed Q16.16
    wire signed [31:0] sx1 = x1;
    wire signed [31:0] sy1 = y1;
    wire signed [31:0] sx2 = x2;
    wire signed [31:0] sy2 = y2;
    wire signed [31:0] spx = px;
    wire signed [31:0] spy = py;

    // Mirror direction vector (Q16.16)
    wire signed [31:0] dx = sx2 - sx1;
    wire signed [31:0] dy = sy2 - sy1;

    // Pre-compute squared length L2 = dx^2 + dy^2 (Q32.32)
    wire signed [63:0] dx2 = $signed(dx) * $signed(dx); // Q32.32
    wire signed [63:0] dy2 = $signed(dy) * $signed(dy); // Q32.32
    wire signed [63:0] L2  = dx2 + dy2;                 // Q32.32

    // Vector from mirror point1 to shooter: v = P - A
    wire signed [31:0] vx = spx - sx1; // Q16.16
    wire signed [31:0] vy = spy - sy1; // Q16.16

    // Dot product v·d (Q32.32)
    wire signed [63:0] v_dot_d = $signed(vx) * $signed(dx) + $signed(vy) * $signed(dy);

    // 2*(v·d) (Q33.32)
    wire signed [64:0] two_v_dot_d = {v_dot_d[63], v_dot_d} <<< 1;

    // Compute t = 2*(v·d) / L2  using 32.32 precision (Q33.32 / Q32.32 -> Q33.32)
    // Simple combinational divider (synthesizable if replaced with IP/RTL); here behavioral.
    reg  signed [64:0] t_q33_32; // Q33.32

    // Reflection point R = P - t * d
    // Need t*d: (Q33.32 * Q16.16) -> Q49.48, then align back to Q16.16
    reg  signed [95:0] txd_full;
    reg  signed [95:0] tyd_full;
    reg  signed [31:0] rx; // Q16.16
    reg  signed [31:0] ry; // Q16.16

    // Intersection with x=0 of line from original shooter (px,py) to reflected point (rx,ry)
    // Param eq: S + u*(R-S). Solve for x=0.
    // u = -Sx / (Rx - Sx)
    // y_hit = Sy + u*(Ry - Sy)
    reg  signed [31:0] drx; // Rx - Sx
    reg  signed [31:0] dry; // Ry - Sy

    reg  signed [63:0] num_u;   // numerator for u (Q32.32)
    reg  signed [63:0] den_u;   // denominator for u (Q32.32)
    reg  signed [63:0] u_q32_32;// Q32.32

    reg  signed [63:0] u_mul_dy;// (u * dry) (Q32.32 * Q16.16 -> Q48.48)
    reg  signed [31:0] y_hit;   // Q16.16

    // Helper: signed division with 32.32 result from 64-bit numerator and 64-bit denom.
    function automatic signed [63:0] div_q32_32;
        input signed [63:0] num;
        input signed [63:0] den;
        reg   signed [127:0] num_ext;
        begin
            if (den == 0) begin
                div_q32_32 = 64'sh0;
            end else begin
                // Scale numerator by 2^32 to keep 32.32 precision
                num_ext = $signed(num);
                num_ext = num_ext <<< 32;
                div_q32_32 = num_ext / $signed(den);
            end
        end
    endfunction

    // Helper: signed division with 33.32 result from 65-bit num and 64-bit den
    function automatic signed [64:0] div_q33_32;
        input signed [64:0] num;
        input signed [63:0] den;
        reg   signed [127:0] num_ext;
        begin
            if (den == 0) begin
                div_q33_32 = 65'sh0;
            end else begin
                num_ext = $signed(num);
                num_ext = num_ext <<< 32; // keep .32 fractional
                div_q33_32 = num_ext / $signed(den);
            end
        end
    endfunction

    always @* begin
        // Default outputs
        valid_hit = 1'b0;
        inf_low   = 1'b0;
        inf_high  = 1'b0;
        y_low     = 32'sd0;
        y_high    = 32'sd0;

        // Degenerate mirror check: if L2 == 0, no well-defined mirror
        if (L2 == 64'sd0) begin
            // No valid reflection
            valid_hit = 1'b0;
        end else begin
            // Compute t = 2*(v·d)/L2 in Q33.32
            t_q33_32 = div_q33_32(two_v_dot_d, L2);

            // t * d (Q33.32 * Q16.16 -> Q49.48)
            txd_full = $signed(t_q33_32) * $signed(dx);
            tyd_full = $signed(t_q33_32) * $signed(dy);

            // Align back to Q16.16: shift right by 32 (from .48 to .16)
            rx = spx - $signed(txd_full[47:16]);
            ry = spy - $signed(tyd_full[47:16]);

            // Direction from shooter to reflected point
            drx = rx - spx;
            dry = ry - spy;

            // If drx == 0, line is vertical; either never hits x=0 or is already on x=0.
            if (drx == 32'sd0) begin
                // If shooter already at x=0, entire line is x=0: infinite valid range at y=py
                if (spx == 32'sd0) begin
                    valid_hit = 1'b1;
                    inf_low   = 1'b1;
                    inf_high  = 1'b1;
                    y_low     = spy;
                    y_high    = spy;
                end else begin
                    // Parallel to wall, no intersection
                    valid_hit = 1'b0;
                end
            end else begin
                // Compute u = -Sx / (Rx - Sx)
                // Use Q32.32 division
                num_u = -$signed(spx);      // Q16.16 -> as 32, treat as Q16.16; extend to 64
                num_u = num_u <<< 16;       // to Q32.32
                den_u = $signed(drx);       // Q16.16
                den_u = den_u <<< 16;       // to Q32.32
                u_q32_32 = div_q32_32(num_u, den_u);

                // Check if intersection is along the ray from shooter to reflection point: u in [0,1]
                if (u_q32_32 < 64'sd0 || u_q32_32 > 64'sh0000000100000000) begin
                    // Outside segment, no valid reflection hit
                    valid_hit = 1'b0;
                end else begin
                    // y_hit = Sy + u*(Ry - Sy)
                    // Compute u*dY: (Q32.32 * Q16.16 -> Q48.48)
                    u_mul_dy = $signed(u_q32_32) * $signed(dry);
                    // Convert to Q16.16: shift right by 32 (48-16)
                    y_hit = spy + $signed(u_mul_dy[47:16]);

                    // For infinite wall at x=0, the hit is a single point; encode as finite bounds
                    valid_hit = 1'b1;
                    inf_low   = 1'b0;
                    inf_high  = 1'b0;
                    y_low     = y_hit;
                    y_high    = y_hit;
                end
            end
        end
    end

endmodule