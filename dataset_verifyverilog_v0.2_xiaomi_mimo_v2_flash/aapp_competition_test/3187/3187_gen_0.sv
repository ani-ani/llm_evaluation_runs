module protest_location (
    input [15:0] x0, y0,
    input [15:0] x1, y1,
    input [15:0] x2, y2,
    input [15:0] x3, y3,
    input [15:0] x4, y4,
    input [15:0] x5, y5,
    input [15:0] x6, y6,
    input [15:0] x7, y7,
    input [15:0] d_max,
    input [2:0] num_citizens,
    output reg [31:0] min_total_distance,
    output reg valid
);

    integer i, j, k;
    reg signed [15:0] cand_x, cand_y;
    reg signed [31:0] dist_sum;
    reg signed [31:0] current_dist;
    reg signed [15:0] diff_x, diff_y;
    reg constraint_ok;
    reg found_solution;
    reg signed [31:0] best_dist;
    
    reg signed [15:0] cx [0:7];
    reg signed [15:0] cy [0:7];

    always @(*) begin
        cx[0] = x0; cy[0] = y0;
        cx[1] = x1; cy[1] = y1;
        cx[2] = x2; cy[2] = y2;
        cx[3] = x3; cy[3] = y3;
        cx[4] = x4; cy[4] = y4;
        cx[5] = x5; cy[5] = y5;
        cx[6] = x6; cy[6] = y6;
        cx[7] = x7; cy[7] = y7;

        best_dist = 32'h7FFFFFFF;
        found_solution = 0;

        for (i = 0; i < 8; i = i + 1) begin
            if (i < num_citizens) begin
                cand_x = cx[i];
                for (j = 0; j < 8; j = j + 1) begin
                    if (j < num_citizens) begin
                        cand_y = cy[j];
                        dist_sum = 0;
                        constraint_ok = 1;
                        for (k = 0; k < 8; k = k + 1) begin
                            if (k < num_citizens) begin
                                diff_x = cx[k] - cand_x;
                                if (diff_x[15]) diff_x = -diff_x;
                                diff_y = cy[k] - cand_y;
                                if (diff_y[15]) diff_y = -diff_y;
                                current_dist = {16'h0, diff_x} + {16'h0, diff_y};
                                if (current_dist > {16'h0, d_max}) begin
                                    constraint_ok = 0;
                                end
                                dist_sum = dist_sum + current_dist;
                            end
                        end
                        if (constraint_ok) begin
                            if (dist_sum < best_dist) begin
                                best_dist = dist_sum;
                                found_solution = 1;
                            end
                        end
                    end
                end
            end
        end
        min_total_distance = best_dist;
        valid = found_solution;
    end

endmodule