module protest_location (
    input [15:0] x0, y0,  // Citizen 0 coordinates
    input [15:0] x1, y1,  // Citizen 1 coordinates
    input [15:0] x2, y2,  // Citizen 2 coordinates
    input [15:0] x3, y3,  // Citizen 3 coordinates
    input [15:0] x4, y4,  // Citizen 4 coordinates
    input [15:0] x5, y5,  // Citizen 5 coordinates
    input [15:0] x6, y6,  // Citizen 6 coordinates
    input [15:0] x7, y7,  // Citizen 7 coordinates
    input [15:0] d_max,   // Maximum allowed distance per citizen
    input [2:0] num_citizens, // Number of active citizens (1-8, 0 means none)
    output reg [31:0] min_total_distance, // Minimum total distance found
    output reg valid // 1 if valid solution exists, 0 if impossible
);

    // Internal signals for candidate generation
    // We generate a grid of candidate locations based on citizen coordinates
    // For small scale, we check all x coordinates from citizens and y from citizens
    // Max 8x8 = 64 candidates

    // To make it combinational and feasible, we check a limited set of candidate points
    // derived from citizen coordinates +/- offset to ensure coverage

    integer i, j, k;
    reg signed [15:0] cand_x, cand_y;
    reg signed [31:0] dist_sum;
    reg signed [31:0] current_dist;
    reg signed [15:0] diff_x, diff_y;
    reg constraint_ok;
    reg found_solution;
    reg signed [31:0] best_dist;

    // Arrays to hold citizen coordinates for iteration
    reg signed [15:0] cx [0:7];
    reg signed [15:0] cy [0:7];

    // Pre-computed candidate coordinates list (simplified grid)
    // We use the median x and y as a heuristic center, plus offset range
    // In a real hardware implementation for 8 nodes, we'd unroll this completely
    // Here we use a procedural block to describe the combinational behavior
    // However, strict Verilog requires unrolling or explicit logic.

    // Given the complexity of dynamic sorting in combinational logic,
    // we will compute the solution by checking a fixed set of candidate points:
    // The center (mean rounded) and points around it.

    // Actually, the most robust way for 8 inputs is to check all valid (x,y) pairs
    // where x is one of the citizen Xs and y is one of the citizen Ys.
    // This is the "L1 geometry" property: the optimal x is one of the citizen x's.
    // This reduces the search space to 64 points.

    always @(*) begin
        // Initialize inputs to arrays for easier access
        cx[0] = x0; cy[0] = y0;
        cx[1] = x1; cy[1] = y1;
        cx[2] = x2; cy[2] = y2;
        cx[3] = x3; cy[3] = y3;
        cx[4] = x4; cy[4] = y4;
        cx[5] = x5; cy[5] = y5;
        cx[6] = x6; cy[6] = y6;
        cx[7] = x7; cy[7] = y7;

        best_dist = 32'h7FFFFFFF; // Max int
        found_solution = 0;

        // Outer loop: iterate through potential x coordinates (from inputs)
        for (i = 0; i < 8; i = i + 1) begin
            // Optimization: If we have fewer citizens, skip remaining indices if they are 0 or garbage
            // For simplicity in this spec, we iterate all 8 but will mask later
            if (i < num_citizens) begin
                cand_x = cx[i];

                // Inner loop: iterate through potential y coordinates (from inputs)
                for (j = 0; j < 8; j = j + 1) begin
                    if (j < num_citizens) begin
                        cand_y = cy[j];

                        // Now check constraints and sum distances for this candidate (cand_x, cand_y)
                        dist_sum = 0;
                        constraint_ok = 1;

                        for (k = 0; k < 8; k = k + 1) begin
                            if (k < num_citizens) begin
                                // Manhattan distance: |x - cand_x| + |y - cand_y|
                                diff_x = cx[k] - cand_x;
                                if (diff_x < 0) diff_x = -diff_x;
                                diff_y = cy[k] - cand_y;
                                if (diff_y < 0) diff_y = -diff_y;

                                current_dist = {16'h0, diff_x} + {16'h0, diff_y};

                                // Check constraint: distance must be <= d_max
                                if (current_dist > {16'h0, d_max}) begin
                                    constraint_ok = 0;
                                end

                                dist_sum = dist_sum + current_dist;
                            end
                        end

                        // If valid and better than current best
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