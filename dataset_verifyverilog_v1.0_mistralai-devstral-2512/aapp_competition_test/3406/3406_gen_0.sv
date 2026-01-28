module CastleCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] polygon_verts [0:7],
    input wire [15:0] castle_x,
    input wire [15:0] castle_y,
    input wire [2:0] num_verts,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LATCH = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] latched_verts [0:7];
    reg [15:0] latched_castle_x, latched_castle_y;
    reg [2:0] latched_num_verts;
    reg [2:0] edge_counter;
    reg [15:0] v1_x, v1_y, v2_x, v2_y;
    reg intersection_count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            edge_counter <= 3'd0;
            intersection_count <= 1'b0;
            cycle_count <= 8'd0;
            for (integer i = 0; i < 8; i = i + 1) begin
                latched_verts[i] <= 16'd0;
            end
            latched_castle_x <= 16'd0;
            latched_castle_y <= 16'd0;
            latched_num_verts <= 3'd0;
            v1_x <= 16'd0;
            v1_y <= 16'd0;
            v2_x <= 16'd0;
            v2_y <= 16'd0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = LATCH;
                end
            end

            LATCH: begin
                for (integer i = 0; i < 8; i = i + 1) begin
                    latched_verts[i] = polygon_verts[i];
                end
                latched_castle_x = castle_x;
                latched_castle_y = castle_y;
                latched_num_verts = num_verts;
                edge_counter = 3'd0;
                intersection_count = 1'b0;
                cycle_count = 8'd0;
                next_state = COMPUTE;
            end

            COMPUTE: begin
                // Get current edge vertices
                v1_x = latched_verts[edge_counter];
                v1_y = latched_verts[edge_counter + 8];
                if (edge_counter == latched_num_verts - 1) begin
                    v2_x = latched_verts[0];
                    v2_y = latched_verts[8];
                end else begin
                    v2_x = latched_verts[edge_counter + 1];
                    v2_y = latched_verts[edge_counter + 9];
                end

                // Check if point is on the edge (colinear and within bounding box)
                reg on_edge;
                wire signed [31:0] cross_product;
                wire signed [31:0] dot_product;
                wire signed [31:0] min_x, max_x, min_y, max_y;

                // Cross product for colinearity check
                assign cross_product = ({1'b0, latched_castle_x} - {1'b0, v1_x}) * ({1'b0, latched_castle_y} - {1'b0, v2_y}) - 
                                      ({1'b0, latched_castle_y} - {1'b0, v1_y}) * ({1'b0, latched_castle_x} - {1'b0, v2_x});

                // Dot product for bounding box check
                assign dot_product = ({1'b0, latched_castle_x} - {1'b0, v1_x}) * ({1'b0, v2_x} - {1'b0, v1_x}) + 
                                    ({1'b0, latched_castle_y} - {1'b0, v1_y}) * ({1'b0, v2_y} - {1'b0, v1_y});

                // Bounding box of edge
                assign min_x = (v1_x < v2_x) ? v1_x : v2_x;
                assign max_x = (v1_x > v2_x) ? v1_x : v2_x;
                assign min_y = (v1_y < v2_y) ? v1_y : v2_y;
                assign max_y = (v1_y > v2_y) ? v1_y : v2_y;

                // Check if point is on edge
                on_edge = (cross_product == 32'd0) && 
                          (dot_product >= 32'd0) && 
                          (dot_product <= ({1'b0, v2_x} - {1'b0, v1_x}) * ({1'b0, v2_x} - {1'b0, v1_x}) + 
                                          ({1'b0, v2_y} - {1'b0, v1_y}) * ({1'b0, v2_y} - {1'b0, v1_y})) &&
                          (latched_castle_x >= min_x) &&
                          (latched_castle_x <= max_x) &&
                          (latched_castle_y >= min_y) &&
                          (latched_castle_y <= max_y);

                // Ray casting algorithm
                reg intersects;
                wire signed [31:0] edge_cross;
                wire signed [31:0] ray_cross1, ray_cross2;

                // Cross products for orientation
                assign edge_cross = ({1'b0, v2_y} - {1'b0, v1_y}) * ({1'b0, latched_castle_x} - {1'b0, v1_x}) - 
                                   ({1'b0, v2_x} - {1'b0, v1_x}) * ({1'b0, latched_castle_y} - {1'b0, v1_y});

                assign ray_cross1 = ({1'b0, latched_castle_y} - {1'b0, v1_y}) * ({1'b0, 65535} - {1'b0, v1_x}) - 
                                    ({1'b0, latched_castle_x} - {1'b0, v1_x}) * ({1'b0, latched_castle_y} - {1'b0, v1_y});

                assign ray_cross2 = ({1'b0, latched_castle_y} - {1'b0, v2_y}) * ({1'b0, 65535} - {1'b0, v2_x}) - 
                                    ({1'b0, latched_castle_x} - {1'b0, v2_x}) * ({1'b0, latched_castle_y} - {1'b0, v2_y});

                // Check if ray intersects edge
                intersects = (edge_cross == 32'd0) ? 1'b0 : 
                            ((ray_cross1 ^ ray_cross2) < 32'd0) && 
                            ((v1_y > latched_castle_y) != (v2_y > latched_castle_y));

                // Update intersection count
                if (on_edge) begin
                    intersection_count = 1'b1;  // Point is on boundary
                end else if (intersects) begin
                    intersection_count = intersection_count ^ 1'b1;
                end

                // Move to next edge or finish
                if (edge_counter == latched_num_verts - 1) begin
                    next_state = FINISH;
                end else begin
                    edge_counter = edge_counter + 1'b1;
                end

                cycle_count = cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end
            end

            FINISH: begin
                result = intersection_count;
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule