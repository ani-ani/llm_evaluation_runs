module PowerFieldComparator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_a,
    input wire [3:0] n_b,
    input wire [15:0] arr_a_x [0:15],
    input wire [15:0] arr_a_y [0:15],
    input wire [15:0] arr_b_x [0:15],
    input wire [15:0] arr_b_y [0:15],
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_HULL_A = 3'd1;
    localparam [2:0] COMPUTE_HULL_B = 3'd2;
    localparam [2:0] COMPARE_HULLS = 3'd3;
    localparam [2:0] COMPARE_EDGES = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd900;

    // Convex hull storage
    reg [15:0] hull_a_x [0:15];
    reg [15:0] hull_a_y [0:15];
    reg [3:0] hull_a_size;
    reg [15:0] hull_b_x [0:15];
    reg [15:0] hull_b_y [0:15];
    reg [3:0] hull_b_size;

    // Edge vectors
    reg signed [15:0] edge_a_dx [0:15];
    reg signed [15:0] edge_a_dy [0:15];
    reg signed [15:0] edge_b_dx [0:15];
    reg signed [15:0] edge_b_dy [0:15];

    // Comparison variables
    reg [3:0] edge_count_a;
    reg [3:0] edge_count_b;
    reg [3:0] rotation_step;
    reg [3:0] current_edge;
    reg match_found;

    // Cross product and dot product
    reg signed [31:0] cross_product;
    reg signed [31:0] dot_product;

    // Temporary variables for computation
    reg [15:0] temp_x [0:15];
    reg [15:0] temp_y [0:15];
    reg [3:0] temp_size;
    reg [3:0] i, j, k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            hull_a_size <= 4'd0;
            hull_b_size <= 4'd0;
            edge_count_a <= 4'd0;
            edge_count_b <= 4'd0;
            rotation_step <= 4'd0;
            current_edge <= 4'd0;
            match_found <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                hull_a_x[i] <= 16'd0;
                hull_a_y[i] <= 16'd0;
                hull_b_x[i] <= 16'd0;
                hull_b_y[i] <= 16'd0;
                edge_a_dx[i] <= 16'd0;
                edge_a_dy[i] <= 16'd0;
                edge_b_dx[i] <= 16'd0;
                edge_b_dy[i] <= 16'd0;
                temp_x[i] <= 16'd0;
                temp_y[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_HULL_A;
                    end
                end

                COMPUTE_HULL_A: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute convex hull for set A
                    // Step 1: Sort points by x-coordinate
                    for (i = 0; i < n_a; i = i + 1) begin
                        temp_x[i] <= arr_a_x[i];
                        temp_y[i] <= arr_a_y[i];
                    end
                    temp_size <= n_a;

                    // Bubble sort (simplified for hardware)
                    for (i = 0; i < 15; i = i + 1) begin
                        for (j = 0; j < 15 - i; j = j + 1) begin
                            if (temp_x[j] > temp_x[j + 1]) begin
                                // Swap
                                temp_x[j] <= temp_x[j + 1];
                                temp_y[j] <= temp_y[j + 1];
                                temp_x[j + 1] <= temp_x[j];
                                temp_y[j + 1] <= temp_y[j];
                            end
                        end
                    end

                    // Step 2: Build lower hull
                    hull_a_size <= 4'd0;
                    for (i = 0; i < temp_size; i = i + 1) begin
                        while (hull_a_size >= 2 && cross_product_func(hull_a_x[hull_a_size - 2], hull_a_y[hull_a_size - 2], hull_a_x[hull_a_size - 1], hull_a_y[hull_a_size - 1], temp_x[i], temp_y[i]) <= 0) begin
                            hull_a_size <= hull_a_size - 1;
                        end
                        hull_a_x[hull_a_size] <= temp_x[i];
                        hull_a_y[hull_a_size] <= temp_y[i];
                        hull_a_size <= hull_a_size + 1;
                    end

                    // Step 3: Build upper hull
                    for (i = temp_size - 2; i >= 0; i = i - 1) begin
                        while (hull_a_size >= 2 && cross_product_func(hull_a_x[hull_a_size - 2], hull_a_y[hull_a_size - 2], hull_a_x[hull_a_size - 1], hull_a_y[hull_a_size - 1], temp_x[i], temp_y[i]) <= 0) begin
                            hull_a_size <= hull_a_size - 1;
                        end
                        hull_a_x[hull_a_size] <= temp_x[i];
                        hull_a_y[hull_a_size] <= temp_y[i];
                        hull_a_size <= hull_a_size + 1;
                    end

                    hull_a_size <= hull_a_size - 1; // Remove duplicate point
                    state <= COMPUTE_HULL_B;
                end

                COMPUTE_HULL_B: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute convex hull for set B (same as A)
                    for (i = 0; i < n_b; i = i + 1) begin
                        temp_x[i] <= arr_b_x[i];
                        temp_y[i] <= arr_b_y[i];
                    end
                    temp_size <= n_b;

                    for (i = 0; i < 15; i = i + 1) begin
                        for (j = 0; j < 15 - i; j = j + 1) begin
                            if (temp_x[j] > temp_x[j + 1]) begin
                                temp_x[j] <= temp_x[j + 1];
                                temp_y[j] <= temp_y[j + 1];
                                temp_x[j + 1] <= temp_x[j];
                                temp_y[j + 1] <= temp_y[j];
                            end
                        end
                    end

                    hull_b_size <= 4'd0;
                    for (i = 0; i < temp_size; i = i + 1) begin
                        while (hull_b_size >= 2 && cross_product_func(hull_b_x[hull_b_size - 2], hull_b_y[hull_b_size - 2], hull_b_x[hull_b_size - 1], hull_b_y[hull_b_size - 1], temp_x[i], temp_y[i]) <= 0) begin
                            hull_b_size <= hull_b_size - 1;
                        end
                        hull_b_x[hull_b_size] <= temp_x[i];
                        hull_b_y[hull_b_size] <= temp_y[i];
                        hull_b_size <= hull_b_size + 1;
                    end

                    for (i = temp_size - 2; i >= 0; i = i - 1) begin
                        while (hull_b_size >= 2 && cross_product_func(hull_b_x[hull_b_size - 2], hull_b_y[hull_b_size - 2], hull_b_x[hull_b_size - 1], hull_b_y[hull_b_size - 1], temp_x[i], temp_y[i]) <= 0) begin
                            hull_b_size <= hull_b_size - 1;
                        end
                        hull_b_x[hull_b_size] <= temp_x[i];
                        hull_b_y[hull_b_size] <= temp_y[i];
                        hull_b_size <= hull_b_size + 1;
                    end

                    hull_b_size <= hull_b_size - 1;
                    state <= COMPARE_HULLS;
                end

                COMPARE_HULLS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (hull_a_size != hull_b_size) begin
                        result <= 1'b0;
                        state <= FINISH;
                    end else begin
                        // Extract edge vectors
                        edge_count_a <= hull_a_size;
                        edge_count_b <= hull_b_size;

                        for (i = 0; i < hull_a_size; i = i + 1) begin
                            j <= (i + 1) % hull_a_size;
                            edge_a_dx[i] <= hull_a_x[j] - hull_a_x[i];
                            edge_a_dy[i] <= hull_a_y[j] - hull_a_y[i];
                        end

                        for (i = 0; i < hull_b_size; i = i + 1) begin
                            j <= (i + 1) % hull_b_size;
                            edge_b_dx[i] <= hull_b_x[j] - hull_b_x[i];
                            edge_b_dy[i] <= hull_b_y[j] - hull_b_y[i];
                        end

                        state <= COMPARE_EDGES;
                    end
                end

                COMPARE_EDGES: begin
                    cycle_count <= cycle_count + 8'd1;
                    match_found <= 1'b0;
                    rotation_step <= 4'd0;

                    // Try all rotations of hull B
                    for (rotation_step = 0; rotation_step < hull_b_size; rotation_step = rotation_step + 1) begin
                        match_found <= 1'b1;
                        for (current_edge = 0; current_edge < hull_a_size; current_edge = current_edge + 1) begin
                            j <= (current_edge + rotation_step) % hull_b_size;
                            cross_product <= edge_a_dx[current_edge] * edge_b_dy[j] - edge_a_dy[current_edge] * edge_b_dx[j];
                            dot_product <= edge_a_dx[current_edge] * edge_b_dx[j] + edge_a_dy[current_edge] * edge_b_dy[j];

                            // Check if edges are parallel and same length
                            if (cross_product != 0 || dot_product != (edge_a_dx[current_edge] * edge_a_dx[current_edge] + edge_a_dy[current_edge] * edge_a_dy[current_edge])) begin
                                match_found <= 1'b0;
                            end
                        end

                        if (match_found) begin
                            result <= 1'b1;
                            state <= FINISH;
                        end
                    end

                    if (!match_found) begin
                        result <= 1'b0;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Cross product function
    function signed [31:0] cross_product_func;
        input [15:0] ax, ay, bx, by, cx, cy;
        begin
            cross_product_func = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
        end
    endfunction

endmodule