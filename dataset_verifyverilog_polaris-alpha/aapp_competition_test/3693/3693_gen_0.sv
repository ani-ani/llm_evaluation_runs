module square_intersection(
    input  signed [7:0] square1 [0:7],
    input  signed [7:0] square2 [0:7],
    output        intersect
);
    // Extract square1 coordinates (axis-aligned square)
    wire signed [7:0] x1_0 = square1[0];
    wire signed [7:0] y1_0 = square1[1];
    wire signed [7:0] x1_1 = square1[2];
    wire signed [7:0] y1_1 = square1[3];
    wire signed [7:0] x1_2 = square1[4];
    wire signed [7:0] y1_2 = square1[5];
    wire signed [7:0] x1_3 = square1[6];
    wire signed [7:0] y1_3 = square1[7];

    // Min/Max helpers for 8-bit signed
    function automatic signed [7:0] min2_8;
        input signed [7:0] a, b;
        begin
            min2_8 = (a < b) ? a : b;
        end
    endfunction

    function automatic signed [7:0] max2_8;
        input signed [7:0] a, b;
        begin
            max2_8 = (a > b) ? a : b;
        end
    endfunction

    // Square1 ranges
    wire signed [7:0] min_x1_step1 = min2_8(x1_0, x1_1);
    wire signed [7:0] min_x1_step2 = min2_8(x1_2, x1_3);
    wire signed [7:0] min_x1       = min2_8(min_x1_step1, min_x1_step2);

    wire signed [7:0] max_x1_step1 = max2_8(x1_0, x1_1);
    wire signed [7:0] max_x1_step2 = max2_8(x1_2, x1_3);
    wire signed [7:0] max_x1       = max2_8(max_x1_step1, max_x1_step2);

    wire signed [7:0] min_y1_step1 = min2_8(y1_0, y1_1);
    wire signed [7:0] min_y1_step2 = min2_8(y1_2, y1_3);
    wire signed [7:0] min_y1       = min2_8(min_y1_step1, min_y1_step2);

    wire signed [7:0] max_y1_step1 = max2_8(y1_0, y1_1);
    wire signed [7:0] max_y1_step2 = max2_8(y1_2, y1_3);
    wire signed [7:0] max_y1       = max2_8(max_y1_step1, max_y1_step2);

    // Extract square2 coordinates (45-degree rotated square)
    wire signed [7:0] x2_0 = square2[0];
    wire signed [7:0] y2_0 = square2[1];
    wire signed [7:0] x2_1 = square2[2];
    wire signed [7:0] y2_1 = square2[3];
    wire signed [7:0] x2_2 = square2[4];
    wire signed [7:0] y2_2 = square2[5];
    wire signed [7:0] x2_3 = square2[6];
    wire signed [7:0] y2_3 = square2[7];

    // u = x + y, v = x - y (use 9-bit signed to avoid overflow)
    wire signed [8:0] u0 = x2_0 + y2_0;
    wire signed [8:0] v0 = x2_0 - y2_0;
    wire signed [8:0] u1 = x2_1 + y2_1;
    wire signed [8:0] v1 = x2_1 - y2_1;
    wire signed [8:0] u2 = x2_2 + y2_2;
    wire signed [8:0] v2 = x2_2 - y2_2;
    wire signed [8:0] u3 = x2_3 + y2_3;
    wire signed [8:0] v3 = x2_3 - y2_3;

    // Min/Max helpers for 9-bit signed
    function automatic signed [8:0] min2_9;
        input signed [8:0] a, b;
        begin
            min2_9 = (a < b) ? a : b;
        end
    endfunction

    function automatic signed [8:0] max2_9;
        input signed [8:0] a, b;
        begin
            max2_9 = (a > b) ? a : b;
        end
    endfunction

    // Ranges in (u,v) for square2
    wire signed [8:0] min_u_step1 = min2_9(u0, u1);
    wire signed [8:0] min_u_step2 = min2_9(u2, u3);
    wire signed [8:0] min_u       = min2_9(min_u_step1, min_u_step2);

    wire signed [8:0] max_u_step1 = max2_9(u0, u1);
    wire signed [8:0] max_u_step2 = max2_9(u2, u3);
    wire signed [8:0] max_u       = max2_9(max_u_step1, max_u_step2);

    wire signed [8:0] min_v_step1 = min2_9(v0, v1);
    wire signed [8:0] min_v_step2 = min2_9(v2, v3);
    wire signed [8:0] min_v       = min2_9(min_v_step1, min_v_step2);

    wire signed [8:0] max_v_step1 = max2_9(v0, v1);
    wire signed [8:0] max_v_step2 = max2_9(v2, v3);
    wire signed [8:0] max_v       = max2_9(max_v_step1, max_v_step2);

    // Transform square1 corners into (u,v) space to check overlap with square2
    wire signed [8:0] su0 = x1_0 + y1_0;
    wire signed [8:0] sv0 = x1_0 - y1_0;
    wire signed [8:0] su1 = x1_1 + y1_1;
    wire signed [8:0] sv1 = x1_1 - y1_1;
    wire signed [8:0] su2 = x1_2 + y1_2;
    wire signed [8:0] sv2 = x1_2 - y1_2;
    wire signed [8:0] su3 = x1_3 + y1_3;
    wire signed [8:0] sv3 = x1_3 - y1_3;

    wire signed [8:0] min_su_step1 = min2_9(su0, su1);
    wire signed [8:0] min_su_step2 = min2_9(su2, su3);
    wire signed [8:0] min_su       = min2_9(min_su_step1, min_su_step2);

    wire signed [8:0] max_su_step1 = max2_9(su0, su1);
    wire signed [8:0] max_su_step2 = max2_9(su2, su3);
    wire signed [8:0] max_su       = max2_9(max_su_step1, max_su_step2);

    wire signed [8:0] min_sv_step1 = min2_9(sv0, sv1);
    wire signed [8:0] min_sv_step2 = min2_9(sv2, sv3);
    wire signed [8:0] min_sv       = min2_9(min_sv_step1, min_sv_step2);

    wire signed [8:0] max_sv_step1 = max2_9(sv0, sv1);
    wire signed [8:0] max_sv_step2 = max2_9(sv2, sv3);
    wire signed [8:0] max_sv       = max2_9(max_sv_step1, max_sv_step2);

    // Condition (a): x-range overlap between square1 and square2 (axis projection)
    wire signed [7:0] min_x2 = min2_8(min2_8(x2_0, x2_1), min2_8(x2_2, x2_3));
    wire signed [7:0] max_x2 = max2_8(max2_8(x2_0, x2_1), max2_8(x2_2, x2_3));
    wire cond_a = (min_x1 <= max_x2) && (min_x2 <= max_x1);

    // Condition (b): y-range overlap between square1 and square2 (axis projection)
    wire signed [7:0] min_y2 = min2_8(min2_8(y2_0, y2_1), min2_8(y2_2, y2_3));
    wire signed [7:0] max_y2 = max2_8(max2_8(y2_0, y2_1), max2_8(y2_2, y2_3));
    wire cond_b = (min_y1 <= max_y2) && (min_y2 <= max_y1);

    // Condition (c): Overlap in transformed (u,v) coordinates
    wire overlap_u = (min_su <= max_u) && (min_u <= max_su);
    wire overlap_v = (min_sv <= max_v) && (min_v <= max_sv);
    wire cond_c = overlap_u && overlap_v;

    assign intersect = cond_a && cond_b && cond_c;

endmodule