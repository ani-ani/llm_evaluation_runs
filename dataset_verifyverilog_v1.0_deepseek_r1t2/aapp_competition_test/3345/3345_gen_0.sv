module min_distance_dogs (
    input integer shadow_x0, shadow_y0, shadow_x1, shadow_y1,
    input integer lydia_x0, lydia_y0, lydia_x1, lydia_y1,
    output real min_dist
);

real dx_s, dy_s, dx_l, dy_l;
real Ls, Ll, T;
real u_x, u_y, v_x, v_y;
real C_x, C_y;
real w_x, w_y;
real a, b, c;
real t0;
real f0, fT, ft0;
real min_f;
real Ls2, Ll2;

always @(*) begin
    // Compute differences
    dx_s = shadow_x1 - shadow_x0;
    dy_s = shadow_y1 - shadow_y0;
    dx_l = lydia_x1 - lydia_x0;
    dy_l = lydia_y1 - lydia_y0;

    // Compute squared lengths
    Ls2 = dx_s*dx_s + dy_s*dy_s;
    Ll2 = dx_l*dx_l + dy_l*dy_l;

    // Compute lengths
    Ls = $sqrt(Ls2);
    Ll = $sqrt(Ll2);

    // Compute T = min(Ls, Ll)
    if (Ls < Ll) T = Ls;
    else T = Ll;

    // Compute unit vectors
    if (Ls > 0) begin
        u_x = dx_s / Ls;
        u_y = dy_s / Ls;
    end else begin
        u_x = 0;
        u_y = 0;
    end
    if (Ll > 0) begin
        v_x = dx_l / Ll;
        v_y = dy_l / Ll;
    end else begin
        v_x = 0;
        v_y = 0;
    end

    // Compute C = start difference
    C_x = shadow_x0 - lydia_x0;
    C_y = shadow_y0 - lydia_y0;

    // Compute w = u - v
    w_x = u_x - v_x;
    w_y = u_y - v_y;

    // Compute a, b, c
    a = w_x*w_x + w_y*w_y;
    b = 2 * (C_x*w_x + C_y*w_y);
    c = C_x*C_x + C_y*C_y;

    // Compute candidates
    f0 = c;
    fT = a*T*T + b*T + c;

    if (a > 0) begin
        t0 = -b / (2*a);
        if (t0 >= 0 && t0 <= T) begin
            ft0 = c - (b*b)/(4*a);
        end else begin
            ft0 = fT;
        end
    end else begin
        ft0 = fT;
    end

    // Find minimum f
    min_f = f0;
    if (fT < min_f) min_f = fT;
    if (a > 0 && ft0 < min_f) min_f = ft0;

    // Output minimum distance (sqrt of min_f)
    if (min_f >= 0) min_dist = $sqrt(min_f);
    else min_dist = 0;
end

endmodule