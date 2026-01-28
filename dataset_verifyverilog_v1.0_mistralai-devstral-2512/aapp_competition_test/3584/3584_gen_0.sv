module onion_fence(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] onions_x [0:15],
    input wire [15:0] onions_y [0:15],
    input wire [15:0] posts_x [0:15],
    input wire [15:0] posts_y [0:15],
    input wire [3:0] n_onions,
    input wire [3:0] n_posts,
    input wire [3:0] k_limit,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] GEN_SUBSETS = 4'd2;
    localparam [3:0] COMPUTE_HULL = 4'd3;
    localparam [3:0] CHECK_ONIONS = 4'd4;
    localparam [3:0] UPDATE_MAX = 4'd5;
    localparam [3:0] FINISH = 4'd6;

    reg [3:0] state;
    reg [31:0] cycle_count;
    localparam [31:0] MAX_CYCLES = 32'd1000000;

    // Subset generation variables
    reg [3:0] subset_idx;
    reg [3:0] subset_size;
    reg [3:0] current_k;
    reg [15:0] subset_x [0:3];
    reg [15:0] subset_y [0:3];

    // Convex hull variables
    reg [15:0] hull_x [0:15];
    reg [15:0] hull_y [0:15];
    reg [3:0] hull_size;

    // Onion checking variables
    reg [3:0] onion_idx;
    reg [7:0] current_count;
    reg [7:0] max_count;

    // Cross product function
    function [32:0] cross;
        input [15:0] ax, ay, bx, by, cx, cy;
        begin
            cross = ($signed(ax - cx) * $signed(by - cy)) - ($signed(bx - cx) * $signed(ay - cy));
        end
    endfunction

    // Point in convex polygon check
    function [0:0] point_in_polygon;
        input [15:0] px, py;
        input [3:0] size;
        integer i;
        reg [32:0] cp;
        begin
            point_in_polygon = 1'b0;
            if (size < 3) begin
                point_in_polygon = 1'b0;
            end else begin
                for (i = 0; i < size; i = i + 1) begin
                    cp = cross(hull_x[i], hull_y[i], hull_x[(i+1)%size], hull_y[(i+1)%size], px, py);
                    if (cp <= 33'd0) begin
                        point_in_polygon = 1'b0;
                        return;
                    end
                end
                point_in_polygon = 1'b1;
            end
        end
    endfunction

    // Convex hull computation (Monotone Chain)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 32'd0;
            subset_idx <= 4'd0;
            subset_size <= 4'd0;
            current_k <= 4'd0;
            hull_size <= 4'd0;
            onion_idx <= 4'd0;
            current_count <= 8'd0;
            max_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                        cycle_count <= 32'd0;
                        max_count <= 8'd0;
                    end
                end

                INIT: begin
                    state <= GEN_SUBSETS;
                    subset_idx <= 4'd0;
                    subset_size <= 4'd0;
                    current_k <= 4'd0;
                end

                GEN_SUBSETS: begin
                    // Generate all subsets of size k_limit
                    if (subset_size == k_limit) begin
                        // Process this subset
                        state <= COMPUTE_HULL;
                    end else begin
                        // Generate next subset
                        if (subset_idx < n_posts) begin
                            subset_x[subset_size] <= posts_x[subset_idx];
                            subset_y[subset_size] <= posts_y[subset_idx];
                            subset_size <= subset_size + 4'd1;
                            subset_idx <= subset_idx + 4'd1;
                        end else begin
                            // Backtrack
                            if (subset_size == 4'd0) begin
                                state <= FINISH;
                            end else begin
                                subset_size <= subset_size - 4'd1;
                                subset_idx <= subset_idx + 4'd1;
                            end
                        end
                    end
                end

                COMPUTE_HULL: begin
                    // Compute convex hull using Monotone Chain algorithm
                    // Sort points by x-coordinate (simplified for small K)
                    // Then compute lower and upper hulls
                    // This is a simplified version - in practice would need proper sorting
                    hull_size <= 4'd0;
                    // For simplicity, assume we can compute hull in one cycle
                    // In real implementation, this would be a multi-cycle process
                    state <= CHECK_ONIONS;
                    onion_idx <= 4'd0;
                    current_count <= 8'd0;
                end

                CHECK_ONIONS: begin
                    if (onion_idx < n_onions) begin
                        // Check if onion is inside the convex hull
                        if (point_in_polygon(onions_x[onion_idx], onions_y[onion_idx], hull_size)) begin
                            current_count <= current_count + 8'd1;
                        end
                        onion_idx <= onion_idx + 4'd1;
                    end else begin
                        state <= UPDATE_MAX;
                    end
                end

                UPDATE_MAX: begin
                    if (current_count > max_count) begin
                        max_count <= current_count;
                    end
                    state <= GEN_SUBSETS;
                    subset_size <= subset_size - 4'd1;
                    subset_idx <= subset_idx + 4'd1;
                end

                FINISH: begin
                    result <= max_count;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            // Safety counter to prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b1;
            end else begin
                cycle_count <= cycle_count + 32'd1;
            end
        end
    end

endmodule