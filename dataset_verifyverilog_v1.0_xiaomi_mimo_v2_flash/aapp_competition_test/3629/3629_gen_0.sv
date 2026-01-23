module boar_collision(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    input wire [15:0] tree0_x, tree0_y, tree0_r,
    input wire [15:0] tree1_x, tree1_y, tree1_r,
    input wire [15:0] tree2_x, tree2_y, tree2_r,
    input wire [15:0] tree3_x, tree3_y, tree3_r,
    input wire [15:0] tree4_x, tree4_y, tree4_r,
    input wire [15:0] tree5_x, tree5_y, tree5_r,
    input wire [15:0] tree6_x, tree6_y, tree6_r,
    input wire [15:0] tree7_x, tree7_y, tree7_r,
    input wire [15:0] b,
    input wire [15:0] d,
    output reg [31:0] probability,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] INIT_DIR    = 4'd1;
    localparam [3:0] CHECK_TREE  = 4'd2;
    localparam [3:0] CALC_DIST   = 4'd3;
    localparam [3:0] COMPARE     = 4'd4;
    localparam [3:0] COUNT_SAFE  = 4'd5;
    localparam [3:0] NEXT_DIR    = 4'd6;
    localparam [3:0] COMPUTE_PROB = 4'd7;
    localparam [3:0] FINISH      = 4'd8;

    reg [3:0] state, next_state;
    reg [3:0] dir_idx;
    reg [3:0] tree_idx;
    reg [2:0] num_trees;
    reg [7:0] safe_count;
    reg [15:0] b_reg, d_reg;
    
    // Tree storage
    reg signed [15:0] tree_x [0:7];
    reg signed [15:0] tree_y [0:7];
    reg [15:0] tree_r [0:7];
    
    // Direction vectors in Q16.16 format (16 cos, 16 sin)
    reg signed [31:0] dir_cos [0:15];
    reg signed [31:0] dir_sin [0:15];
    
    // Temporary calculation registers
    reg signed [63:0] temp_x;
    reg signed [63:0] temp_y;
    reg signed [63:0] tree_x_ext;
    reg signed [63:0] tree_y_ext;
    reg signed [63:0] end_x;
    reg signed [63:0] end_y;
    reg signed [63:0] dist_sq;
    reg signed [63:0] collision_radius_sq;
    reg collision_detected;
    
    // Cycle counter for safety
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Initialize direction vectors (precomputed)
    initial begin
        // 0 degrees (1, 0)
        dir_cos[0]  = 32'sd65536; dir_sin[0]  = 32'sd0;
        // 22.5 degrees (cos=0.92387953, sin=0.38268343)
        dir_cos[1]  = 32'sd60590; dir_sin[1]  = 32'sd25080;
        // 45 degrees (0.70710678, 0.70710678)
        dir_cos[2]  = 32'sd46341; dir_sin[2]  = 32'sd46341;
        // 67.5 degrees (0.38268343, 0.92387953)
        dir_cos[3]  = 32'sd25080; dir_sin[3]  = 32'sd60590;
        // 90 degrees (0, 1)
        dir_cos[4]  = 32'sd0; dir_sin[4]  = 32'sd65536;
        // 112.5 degrees (-0.38268343, 0.92387953)
        dir_cos[5]  = -32'sd25080; dir_sin[5]  = 32'sd60590;
        // 135 degrees (-0.70710678, 0.70710678)
        dir_cos[6]  = -32'sd46341; dir_sin[6]  = 32'sd46341;
        // 157.5 degrees (-0.92387953, 0.38268343)
        dir_cos[7]  = -32'sd60590; dir_sin[7]  = 32'sd25080;
        // 180 degrees (-1, 0)
        dir_cos[8]  = -32'sd65536; dir_sin[8]  = 32'sd0;
        // 202.5 degrees (-0.92387953, -0.38268343)
        dir_cos[9]  = -32'sd60590; dir_sin[9]  = -32'sd25080;
        // 225 degrees (-0.70710678, -0.70710678)
        dir_cos[10] = -32'sd46341; dir_sin[10] = -32'sd46341;
        // 247.5 degrees (-0.38268343, -0.92387953)
        dir_cos[11] = -32'sd25080; dir_sin[11] = -32'sd60590;
        // 270 degrees (0, -1)
        dir_cos[12] = 32'sd0; dir_sin[12] = -32'sd65536;
        // 292.5 degrees (0.38268343, -0.92387953)
        dir_cos[13] = 32'sd25080; dir_sin[13] = -32'sd60590;
        // 315 degrees (0.70710678, -0.70710678)
        dir_cos[14] = 32'sd46341; dir_sin[14] = -32'sd46341;
        // 337.5 degrees (0.92387953, -0.38268343)
        dir_cos[15] = 32'sd60590; dir_sin[15] = -32'sd25080;
    end

    // State transition and logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            probability <= 32'd0;
            dir_idx <= 4'd0;
            tree_idx <= 4'd0;
            safe_count <= 8'd0;
            num_trees <= 3'd0;
            b_reg <= 16'd0;
            d_reg <= 16'd0;
            cycle_count <= 8'd0;
            collision_detected <= 1'b0;
            end_x <= 64'd0;
            end_y <= 64'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT_DIR;
                        num_trees <= n;
                        b_reg <= b;
                        d_reg <= d;
                        safe_count <= 8'd0;
                        dir_idx <= 4'd0;
                        tree_idx <= 4'd0;
                        collision_detected <= 1'b0;
                        
                        // Store tree parameters
                        tree_x[0] <= tree0_x;
                        tree_y[0] <= tree0_y;
                        tree_r[0] <= tree0_r;
                        tree_x[1] <= tree1_x;
                        tree_y[1] <= tree1_y;
                        tree_r[1] <= tree1_r;
                        tree_x[2] <= tree2_x;
                        tree_y[2] <= tree2_y;
                        tree_r[2] <= tree2_r;
                        tree_x[3] <= tree3_x;
                        tree_y[3] <= tree3_y;
                        tree_r[3] <= tree3_r;
                        tree_x[4] <= tree4_x;
                        tree_y[4] <= tree4_y;
                        tree_r[4] <= tree4_r;
                        tree_x[5] <= tree5_x;
                        tree_y[5] <= tree5_y;
                        tree_r[5] <= tree5_r;
                        tree_x[6] <= tree6_x;
                        tree_y[6] <= tree6_y;
                        tree_r[6] <= tree6_r;
                        tree_x[7] <= tree7_x;
                        tree_y[7] <= tree7_y;
                        tree_r[7] <= tree7_r;
                    end
                end
                
                INIT_DIR: begin
                    cycle_count <= cycle_count + 8'd1;
                    tree_idx <= 4'd0;
                    collision_detected <= 1'b0;
                    
                    // Calculate end point: (cos * d, sin * d) in Q16.16
                    temp_x <= dir_cos[dir_idx] * $signed({16'd0, d_reg});
                    temp_y <= dir_sin[dir_idx] * $signed({16'd0, d_reg});
                    
                    if (num_trees == 3'd0) begin
                        // No trees, this direction is safe
                        state <= NEXT_DIR;
                    end else begin
                        state <= CHECK_TREE;
                    end
                end
                
                CHECK_TREE: begin
                    if (tree_idx >= num_trees) begin
                        // All trees checked for this direction
                        if (!collision_detected) begin
                            safe_count <= safe_count + 8'd1;
                        end
                        state <= NEXT_DIR;
                    end else begin
                        // Prepare distance calculation
                        end_x <= temp_x >>> 16;  // Convert to integer
                        end_y <= temp_y >>> 16;
                        tree_x_ext <= { {48{tree_x[tree_idx][15]}}, tree_x[tree_idx] };
                        tree_y_ext <= { {48{tree_y[tree_idx][15]}}, tree_y[tree_idx] };
                        state <= CALC_DIST;
                    end
                end
                
                CALC_DIST: begin
                    // Calculate squared distance from tree to line segment
                    // Using projection method
                    
                    // Vector from origin to tree center
                    temp_x <= tree_x_ext;
                    temp_y <= tree_y_ext;
                    
                    // Dot product with direction
                    temp_x <= temp_x * end_x;
                    temp_y <= temp_y * end_y;
                    
                    state <= COMPARE;
                end
                
                COMPARE: begin
                    // Calculate collision radius squared
                    collision_radius_sq <= ({16'd0, b_reg} + {16'd0, tree_r[tree_idx]}) *
                                           ({16'd0, b_reg} + {16'd0, tree_r[tree_idx]});
                    
                    // For line segment, check if perpendicular distance < (b + r)
                    // Simplified: check distance from line to tree center
                    // Using: d_perp = |cross_product| / distance_to_end
                    
                    // Check if projection is within [0, 1]
                    // distance squared from tree to endpoint
                    end_x <= end_x - tree_x_ext;
                    end_y <= end_y - tree_y_ext;
                    
                    // Check if line segment is long enough
                    if (end_x < 0) end_x <= -end_x;
                    if (end_y < 0) end_y <= -end_y;
                    
                    // Direct distance check (simplified collision)
                    dist_sq <= end_x * end_x + end_y * end_y;
                    
                    if ((end_x * end_x + end_y * end_y) < (temp_x * temp_x + temp_y * temp_y)) begin
                        // Use endpoint distance
                        if (end_x * end_x + end_y * end_y < collision_radius_sq) begin
                            collision_detected <= 1'b1;
                        end
                    end else begin
                        // Use perpendicular distance approximation
                        if (temp_x * temp_x + temp_y * temp_y < collision_radius_sq) begin
                            collision_detected <= 1'b1;
                        end
                    end
                    
                    tree_idx <= tree_idx + 4'd1;
                    state <= CHECK_TREE;
                end
                
                NEXT_DIR: begin
                    if (dir_idx == 4'd15) begin
                        state <= COMPUTE_PROB;
                    end else begin
                        dir_idx <= dir_idx + 4'd1;
                        state <= INIT_DIR;
                    end
                    
                    // Safety timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= COMPUTE_PROB;
                    end
                end
                
                COMPUTE_PROB: begin
                    // probability = safe_count / 16
                    // In Q16.16: result = (safe_count << 16) / 16
                    probability <= {16'd0, safe_count[7:0], 16'd0} >> 4;
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule