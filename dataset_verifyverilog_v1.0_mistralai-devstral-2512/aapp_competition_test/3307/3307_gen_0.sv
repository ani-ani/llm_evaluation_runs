module PolygonAreaCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] N,
    input wire signed [15:0] xa,
    input wire signed [15:0] ya,
    input wire signed [15:0] xb,
    input wire signed [15:0] yb,
    input wire signed [15:0] arr_x [0:99],
    input wire signed [15:0] arr_y [0:99],
    output reg signed [31:0] result_area,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_REF_DIST = 3'd1;
    localparam [2:0] CLIP_POLYGON = 3'd2;
    localparam [2:0] COMPUTE_AREA = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state, next_state;

    // Internal registers
    reg [7:0] vertex_index;
    reg [7:0] clipped_vertex_count;
    reg signed [15:0] ref_x, ref_y;
    reg signed [15:0] ref_dist;
    reg signed [15:0] clipped_x [0:99];
    reg signed [15:0] clipped_y [0:99];
    reg signed [31:0] area_sum;
    reg signed [15:0] current_x, current_y;
    reg signed [15:0] next_x, next_y;
    reg signed [15:0] intersection_x, intersection_y;
    reg signed [15:0] edge_x, edge_y;
    reg signed [15:0] canal_dx, canal_dy;
    reg signed [31:0] temp_product;
    reg signed [31:0] temp_dividend;
    reg signed [31:0] temp_divisor;
    reg signed [31:0] temp_result;
    reg signed [15:0] temp_x, temp_y;

    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Canal line parameters
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            canal_dx <= 16'd0;
            canal_dy <= 16'd0;
        end else begin
            canal_dx <= xb - xa;
            canal_dy <= yb - ya;
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            vertex_index <= 8'd0;
            clipped_vertex_count <= 8'd0;
            ref_x <= 16'd0;
            ref_y <= 16'd0;
            ref_dist <= 16'd0;
            area_sum <= 32'd0;
            current_x <= 16'd0;
            current_y <= 16'd0;
            next_x <= 16'd0;
            next_y <= 16'd0;
            intersection_x <= 16'd0;
            intersection_y <= 16'd0;
            edge_x <= 16'd0;
            edge_y <= 16'd0;
            temp_product <= 32'd0;
            temp_dividend <= 32'd0;
            temp_divisor <= 32'd0;
            temp_result <= 32'd0;
            temp_x <= 16'd0;
            temp_y <= 16'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            result_area <= 32'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= CALC_REF_DIST;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CALC_REF_DIST: begin
                    // Use first vertex as reference point
                    ref_x <= arr_x[0];
                    ref_y <= arr_y[0];

                    // Calculate reference distance (signed)
                    // Distance = (xb - xa)*(y - ya) - (yb - ya)*(x - xa)
                    temp_product <= (canal_dx * (ref_y - ya)) - (canal_dy * (ref_x - xa));
                    ref_dist <= temp_product[31:16]; // Q16.16 result

                    // Initialize clipped polygon with first vertex
                    clipped_x[0] <= arr_x[0];
                    clipped_y[0] <= arr_y[0];
                    clipped_vertex_count <= 8'd1;
                    vertex_index <= 8'd0;
                    next_state <= CLIP_POLYGON;
                end

                CLIP_POLYGON: begin
                    // Process each edge (vertex_index to vertex_index+1)
                    current_x <= arr_x[vertex_index];
                    current_y <= arr_y[vertex_index];

                    // Get next vertex (wrap around for last edge)
                    if (vertex_index == N - 1) begin
                        next_x <= arr_x[0];
                        next_y <= arr_y[0];
                    end else begin
                        next_x <= arr_x[vertex_index + 1];
                        next_y <= arr_y[vertex_index + 1];
                    end

                    // Calculate distances for current and next vertices
                    temp_product <= (canal_dx * (current_y - ya)) - (canal_dy * (current_x - xa));
                    edge_x <= temp_product[31:16];

                    temp_product <= (canal_dx * (next_y - ya)) - (canal_dy * (next_x - xa));
                    edge_y <= temp_product[31:16];

                    // Determine which side of the line each vertex is on
                    // (sign matches ref_dist)
                    if ((edge_x[15] == ref_dist[15]) && (edge_y[15] == ref_dist[15])) begin
                        // Both vertices on same side as reference
                        // Add next vertex to clipped polygon
                        clipped_x[clipped_vertex_count] <= next_x;
                        clipped_y[clipped_vertex_count] <= next_y;
                        clipped_vertex_count <= clipped_vertex_count + 8'd1;
                    end else if ((edge_x[15] != ref_dist[15]) && (edge_y[15] != ref_dist[15])) begin
                        // Both vertices on opposite side - skip
                    end else begin
                        // Edge crosses the canal line - calculate intersection
                        // Find intersection point using parametric equations
                        // t = (d1) / (d1 - d2)
                        temp_dividend <= edge_x - ref_dist; // d1
                        temp_divisor <= edge_x - edge_y;    // d1 - d2

                        // Avoid division by zero
                        if (temp_divisor == 32'd0) begin
                            // Parallel edge - use midpoint
                            intersection_x <= (current_x + next_x) >> 1;
                            intersection_y <= (current_y + next_y) >> 1;
                        end else begin
                            // Fixed-point division (Q16.16)
                            // Scale numerator by 2^16 for precision
                            temp_result <= (temp_dividend << 16) / temp_divisor;
                            intersection_x <= current_x + ((temp_result * (next_x - current_x)) >> 16);
                            intersection_y <= current_y + ((temp_result * (next_y - current_y)) >> 16);
                        end

                        // Add intersection point
                        clipped_x[clipped_vertex_count] <= intersection_x;
                        clipped_y[clipped_vertex_count] <= intersection_y;
                        clipped_vertex_count <= clipped_vertex_count + 8'd1;

                        // Add next vertex if it's on the correct side
                        if (edge_y[15] == ref_dist[15]) begin
                            clipped_x[clipped_vertex_count] <= next_x;
                            clipped_y[clipped_vertex_count] <= next_y;
                            clipped_vertex_count <= clipped_vertex_count + 8'd1;
                        end
                    end

                    // Move to next vertex
                    if (vertex_index == N - 1) begin
                        next_state <= COMPUTE_AREA;
                    end else begin
                        vertex_index <= vertex_index + 8'd1;
                        next_state <= CLIP_POLYGON;
                    end
                end

                COMPUTE_AREA: begin
                    // Compute area using shoelace formula
                    area_sum <= 32'd0;

                    // Iterate through clipped vertices
                    for (vertex_index = 0; vertex_index < clipped_vertex_count; vertex_index = vertex_index + 1) begin
                        // Get current and next vertices (wrap around)
                        if (vertex_index == clipped_vertex_count - 1) begin
                            temp_x <= clipped_x[0];
                            temp_y <= clipped_y[0];
                        end else begin
                            temp_x <= clipped_x[vertex_index + 1];
                            temp_y <= clipped_y[vertex_index + 1];
                        end

                        // Sum: x_i*y_{i+1} - x_{i+1}*y_i
                        temp_product <= (clipped_x[vertex_index] * temp_y) - (temp_x * clipped_y[vertex_index]);
                        area_sum <= area_sum + temp_product;
                    end

                    // Final area is absolute value divided by 2
                    if (area_sum[31]) begin
                        area_sum <= -area_sum;
                    end
                    result_area <= area_sum >> 1; // Divide by 2
                    next_state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase

            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b0;
            end
        end
    end

    // Initialize clipped vertex arrays
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 100; i = i + 1) begin
                clipped_x[i] <= 16'd0;
                clipped_y[i] <= 16'd0;
            end
        end
    end

endmodule