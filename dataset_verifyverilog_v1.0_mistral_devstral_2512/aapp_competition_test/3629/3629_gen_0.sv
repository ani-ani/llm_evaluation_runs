module boar_collision(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    input wire signed [15:0] tree0_x, tree0_y,
    input wire signed [15:0] tree1_x, tree1_y,
    input wire signed [15:0] tree2_x, tree2_y,
    input wire signed [15:0] tree3_x, tree3_y,
    input wire signed [15:0] tree4_x, tree4_y,
    input wire signed [15:0] tree5_x, tree5_y,
    input wire signed [15:0] tree6_x, tree6_y,
    input wire signed [15:0] tree7_x, tree7_y,
    input wire [15:0] tree0_r, tree1_r, tree2_r, tree3_r,
    input wire [15:0] tree4_r, tree5_r, tree6_r, tree7_r,
    input wire [15:0] b,
    input wire [15:0] d,
    output reg [31:0] probability,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Direction vectors (16 directions, 16.16 fixed-point)
    localparam signed [31:0] dir_x [0:15] = '{16'd32768, 16'd30274, 16'd22544, 16'd11931, 16'd0, -16'd11931, -16'd22544, -16'd30274, -16'd32768, -16'd30274, -16'd22544, -16'd11931, 16'd0, 16'd11931, 16'd22544, 16'd30274};
    localparam signed [31:0] dir_y [0:15] = '{16'd0, 16'd11931, 16'd22544, 16'd30274, 16'd32768, 16'd30274, 16'd22544, 16'd11931, 16'd0, -16'd11931, -16'd22544, -16'd30274, -16'd32768, -16'd30274, -16'd22544, -16'd11931};

    reg [3:0] dir_idx;
    reg [3:0] tree_idx;
    reg [31:0] safe_count;
    reg [31:0] end_x, end_y;
    reg [63:0] dist_sq, tree_dist_sq;
    reg [31:0] tree_r_plus_b_sq;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            probability <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            dir_idx <= 4'd0;
            tree_idx <= 4'd0;
            safe_count <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        dir_idx <= 4'd0;
                        tree_idx <= 4'd0;
                        safe_count <= 32'd0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Compute end point for current direction
                    end_x <= dir_x[dir_idx] * d;
                    end_y <= dir_y[dir_idx] * d;

                    // Check collision with current tree
                    if (tree_idx < n) begin
                        // Compute squared distance from origin to tree center
                        dist_sq <= {16'd0, tree0_x} * {16'd0, tree0_x} + {16'd0, tree0_y} * {16'd0, tree0_y};
                        // Compute squared distance from tree center to line segment
                        // Using vector projection method
                        tree_dist_sq <= dist_sq - ({16'd0, tree0_x} * end_x + {16'd0, tree0_y} * end_y) * ({16'd0, tree0_x} * end_x + {16'd0, tree0_y} * end_y) / (end_x * end_x + end_y * end_y);
                        // Compute (tree_r + b)^2
                        tree_r_plus_b_sq <= (tree0_r + b) * (tree0_r + b);

                        // Check if collision occurs
                        if (tree_dist_sq < tree_r_plus_b_sq) begin
                            // Collision detected, move to next direction
                            dir_idx <= dir_idx + 4'd1;
                            tree_idx <= 4'd0;
                        end else begin
                            // No collision, check next tree
                            tree_idx <= tree_idx + 4'd1;
                        end
                    end else begin
                        // No collision with any tree, increment safe count
                        safe_count <= safe_count + 32'd1;
                        dir_idx <= dir_idx + 4'd1;
                        tree_idx <= 4'd0;
                    end

                    // Check if all directions processed
                    if (dir_idx == 4'd16 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    // Compute probability = safe_count / 16
                    probability <= safe_count << 16;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule