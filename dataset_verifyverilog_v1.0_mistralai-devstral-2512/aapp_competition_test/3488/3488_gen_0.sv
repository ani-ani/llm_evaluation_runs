module ConvexPolygonSubset(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [3:0] K,
    input wire signed [15:0] vertices_x [0:15],
    input wire signed [15:0] vertices_y [0:15],
    input wire signed [15:0] points_x [0:15],
    input wire signed [15:0] points_y [0:15],
    output reg [4:0] result,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] GENERATE = 3'd1;
    localparam [2:0] CHECK = 3'd2;
    localparam [2:0] UPDATE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [15:0] mask;
    reg [4:0] min_vertices;
    reg [4:0] current_count;
    reg [3:0] vertex_index;
    reg [3:0] point_index;
    reg [3:0] subset_index;
    reg [3:0] subset_size;
    reg convex_flag;
    reg all_inside_flag;
    reg [15:0] subset_x [0:15];
    reg [15:0] subset_y [0:15];
    reg [15:0] temp_x [0:15];
    reg [15:0] temp_y [0:15];

    // Fixed-point arithmetic helpers
    function signed [31:0] multiply_q16_16(input signed [15:0] a, input signed [15:0] b);
        multiply_q16_16 = $signed({a, 16'd0}) * $signed({b, 16'd0});
    endfunction

    function signed [15:0] cross_product(input signed [15:0] ax, input signed [15:0] ay, 
                                         input signed [15:0] bx, input signed [15:0] by, 
                                         input signed [15:0] cx, input signed [15:0] cy);
        signed [31:0] abx, aby, acx, acy;
        abx = multiply_q16_16(bx - ax, cy - ay);
        aby = multiply_q16_16(by - ay, cx - ax);
        cross_product = (abx - aby) >> 16;
    endfunction

    // Check if point is inside polygon
    function reg point_in_polygon(input signed [15:0] px, input signed [15:0] py,
                                  input signed [15:0] poly_x [0:15], 
                                  input signed [15:0] poly_y [0:15],
                                  input [3:0] size);
        integer i;
        reg inside;
        signed [15:0] x0, y0, x1, y1;
        signed [15:0] cross;
        integer count;

        inside = 1'b0;
        count = 0;

        for (i = 0; i < size; i = i + 1) begin
            x0 = poly_x[i];
            y0 = poly_y[i];
            x1 = poly_x[(i + 1) % size];
            y1 = poly_y[(i + 1) % size];

            // Check if point is on the edge
            cross = cross_product(x0, y0, x1, y1, px, py);
            if (cross == 16'd0) begin
                // Check if point is on the segment
                if (((px >= x0 && px <= x1) || (px <= x0 && px >= x1)) &&
                    ((py >= y0 && py <= y1) || (py <= y0 && py >= y1))) begin
                    inside = 1'b1;
                    return inside;
                end
            end

            // Ray casting algorithm
            if (((y0 > py) != (y1 > py)) &&
                (px < (x1 - x0) * (py - y0) / (y1 - y0) + x0)) begin
                count = count + 1;
            end
        end

        inside = (count % 2) == 1;
        return inside;
    endfunction

    // Check if subset forms convex polygon
    function reg is_convex(input signed [15:0] poly_x [0:15], 
                           input signed [15:0] poly_y [0:15],
                           input [3:0] size);
        integer i;
        signed [15:0] cross;
        reg [15:0] prev_cross;
        reg consistent;

        if (size < 3) begin
            return 1'b0;
        end

        consistent = 1'b1;
        prev_cross = 1'b0;

        for (i = 0; i < size; i = i + 1) begin
            cross = cross_product(poly_x[i], poly_y[i], 
                                 poly_x[(i + 1) % size], poly_y[(i + 1) % size],
                                 poly_x[(i + 2) % size], poly_y[(i + 2) % size]);

            if (i == 0) begin
                prev_cross = cross > 16'd0 ? 1'b1 : (cross < 16'd0 ? 1'b0 : prev_cross);
            end else begin
                if ((cross > 16'd0 && !prev_cross) || (cross < 16'd0 && prev_cross)) begin
                    consistent = 1'b0;
                    return consistent;
                end
            end
        end

        return consistent;
    endfunction

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            valid <= 1'b0;
            mask <= 16'd0;
            min_vertices <= 5'd16;
            current_count <= 5'd0;
            vertex_index <= 4'd0;
            point_index <= 4'd0;
            subset_index <= 4'd0;
            subset_size <= 4'd0;
            convex_flag <= 1'b0;
            all_inside_flag <= 1'b1;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = GENERATE;
                    mask = 16'd1;
                    min_vertices = 5'd16;
                    subset_index = 4'd0;
                end
            end

            GENERATE: begin
                if (subset_index == (1 << N) - 1) begin
                    next_state = DONE_STATE;
                end else begin
                    // Build subset from mask
                    subset_size = 4'd0;
                    for (integer i = 0; i < 16; i = i + 1) begin
                        if (mask[i]) begin
                            temp_x[subset_size] = vertices_x[i];
                            temp_y[subset_size] = vertices_y[i];
                            subset_size = subset_size + 1;
                        end
                    end

                    if (subset_size >= 3) begin
                        // Copy to subset arrays
                        for (integer i = 0; i < subset_size; i = i + 1) begin
                            subset_x[i] = temp_x[i];
                            subset_y[i] = temp_y[i];
                        end
                        next_state = CHECK;
                        vertex_index = 4'd0;
                        point_index = 4'd0;
                        convex_flag = is_convex(temp_x, temp_y, subset_size);
                        all_inside_flag = 1'b1;
                    end else begin
                        next_state = GENERATE;
                        mask = mask + 16'd1;
                        subset_index = subset_index + 1;
                    end
                end
            end

            CHECK: begin
                if (convex_flag && all_inside_flag) begin
                    next_state = UPDATE;
                end else if (!convex_flag) begin
                    next_state = GENERATE;
                    mask = mask + 16'd1;
                    subset_index = subset_index + 1;
                end else begin
                    // Check if current point is inside
                    if (point_in_polygon(points_x[point_index], points_y[point_index], 
                                        temp_x, temp_y, subset_size)) begin
                        if (point_index == K - 1) begin
                            all_inside_flag = 1'b1;
                        end else begin
                            point_index = point_index + 1;
                        end
                    end else begin
                        all_inside_flag = 1'b0;
                        next_state = GENERATE;
                        mask = mask + 16'd1;
                        subset_index = subset_index + 1;
                    end
                end
            end

            UPDATE: begin
                current_count = subset_size;
                if (current_count < min_vertices) begin
                    min_vertices = current_count;
                end
                next_state = GENERATE;
                mask = mask + 16'd1;
                subset_index = subset_index + 1;
            end

            DONE_STATE: begin
                result = min_vertices;
                done = 1'b1;
                valid = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule