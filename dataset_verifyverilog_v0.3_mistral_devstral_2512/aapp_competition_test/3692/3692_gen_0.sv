module CircleRegions(
    input [1:0] n,
    input signed [7:0] x1, y1, r1,
    input signed [7:0] x2, y2, r2,
    input signed [7:0] x3, y3, r3,
    output reg [7:0] result
);

    reg [7:0] regions;
    reg [15:0] dx12, dy12, dist_sq12, sum_r12, diff_r12, sum_sq12, diff_sq12;
    reg [15:0] dx13, dy13, dist_sq13, sum_r13, diff_r13, sum_sq13, diff_sq13;
    reg [15:0] dx23, dy23, dist_sq23, sum_r23, diff_r23, sum_sq23, diff_sq23;
    reg intersect12, intersect13, intersect23;
    reg separate12, separate13, separate23;
    reg contain12, contain13, contain23;

    always @(*) begin
        case (n)
            2'd1: regions = 8'd2;
            2'd2: begin
                dx12 = $signed(x1) - $signed(x2);
                dy12 = $signed(y1) - $signed(y2);
                dist_sq12 = dx12 * dx12 + dy12 * dy12;
                sum_r12 = $signed(r1) + $signed(r2);
                diff_r12 = $signed(r1) - $signed(r2);
                sum_sq12 = sum_r12 * sum_r12;
                diff_sq12 = diff_r12 * diff_r12;

                intersect12 = (dist_sq12 < sum_sq12) && (dist_sq12 > diff_sq12);
                separate12 = dist_sq12 >= sum_sq12;
                contain12 = (dist_sq12 <= diff_sq12) && (diff_r12 >= 0);

                if (intersect12) regions = 8'd4;
                else if (separate12) regions = 8'd4;
                else if (contain12) regions = 8'd2;
                else regions = 8'd2;
            end
            2'd3: begin
                dx12 = $signed(x1) - $signed(x2);
                dy12 = $signed(y1) - $signed(y2);
                dist_sq12 = dx12 * dx12 + dy12 * dy12;
                sum_r12 = $signed(r1) + $signed(r2);
                diff_r12 = $signed(r1) - $signed(r2);
                sum_sq12 = sum_r12 * sum_r12;
                diff_sq12 = diff_r12 * diff_r12;

                dx13 = $signed(x1) - $signed(x3);
                dy13 = $signed(y1) - $signed(y3);
                dist_sq13 = dx13 * dx13 + dy13 * dy13;
                sum_r13 = $signed(r1) + $signed(r3);
                diff_r13 = $signed(r1) - $signed(r3);
                sum_sq13 = sum_r13 * sum_r13;
                diff_sq13 = diff_r13 * diff_r13;

                dx23 = $signed(x2) - $signed(x3);
                dy23 = $signed(y2) - $signed(y3);
                dist_sq23 = dx23 * dx23 + dy23 * dy23;
                sum_r23 = $signed(r2) + $signed(r3);
                diff_r23 = $signed(r2) - $signed(r3);
                sum_sq23 = sum_r23 * sum_r23;
                diff_sq23 = diff_r23 * diff_r23;

                intersect12 = (dist_sq12 < sum_sq12) && (dist_sq12 > diff_sq12);
                intersect13 = (dist_sq13 < sum_sq13) && (dist_sq13 > diff_sq13);
                intersect23 = (dist_sq23 < sum_sq23) && (dist_sq23 > diff_sq23);

                separate12 = dist_sq12 >= sum_sq12;
                separate13 = dist_sq13 >= sum_sq13;
                separate23 = dist_sq23 >= sum_sq23;

                contain12 = (dist_sq12 <= diff_sq12) && (diff_r12 >= 0);
                contain13 = (dist_sq13 <= diff_sq13) && (diff_r13 >= 0);
                contain23 = (dist_sq23 <= diff_sq23) && (diff_r23 >= 0);

                if (intersect12 && intersect13 && intersect23) regions = 8'd8;
                else if (intersect12 && intersect13 && separate23) regions = 8'd8;
                else if (intersect12 && intersect13 && contain23) regions = 8'd6;
                else if (intersect12 && separate13 && intersect23) regions = 8'd8;
                else if (intersect12 && separate13 && separate23) regions = 8'd6;
                else if (intersect12 && separate13 && contain23) regions = 8'd6;
                else if (intersect12 && contain13 && intersect23) regions = 8'd6;
                else if (intersect12 && contain13 && separate23) regions = 8'd6;
                else if (intersect12 && contain13 && contain23) regions = 8'd4;
                else if (separate12 && intersect13 && intersect23) regions = 8'd8;
                else if (separate12 && intersect13 && separate23) regions = 8'd6;
                else if (separate12 && intersect13 && contain23) regions = 8'd6;
                else if (separate12 && separate13 && intersect23) regions = 8'd8;
                else if (separate12 && separate13 && separate23) regions = 8'd8;
                else if (separate12 && separate13 && contain23) regions = 8'd6;
                else if (separate12 && contain13 && intersect23) regions = 8'd6;
                else if (separate12 && contain13 && separate23) regions = 8'd6;
                else if (separate12 && contain13 && contain23) regions = 8'd4;
                else if (contain12 && intersect13 && intersect23) regions = 8'd6;
                else if (contain12 && intersect13 && separate23) regions = 8'd6;
                else if (contain12 && intersect13 && contain23) regions = 8'd4;
                else if (contain12 && separate13 && intersect23) regions = 8'd6;
                else if (contain12 && separate13 && separate23) regions = 8'd4;
                else if (contain12 && separate13 && contain23) regions = 8'd4;
                else if (contain12 && contain13 && intersect23) regions = 8'd4;
                else if (contain12 && contain13 && separate23) regions = 8'd4;
                else if (contain12 && contain13 && contain23) regions = 8'd2;
                else regions = 8'd8;
            end
            default: regions = 8'd0;
        endcase
        result = regions;
    end
endmodule