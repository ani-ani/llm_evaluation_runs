module BoarChargeProbability(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [23:0] b_radius,
    input wire [23:0] d_distance,
    input wire [23:0] tree_x [0:7],
    input wire [23:0] tree_y [0:7],
    input wire [23:0] tree_r [0:7],
    input wire [3:0] num_trees,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE_ANGLE = 3'd2;
    localparam [2:0] COMPUTE_TREE = 3'd3;
    localparam [2:0] CALC_PROB = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Precomputed cos and sin tables (Q12.12 format)
    localparam [23:0] cos_table [0:255] = '{24'd4096, 24'd4095, 24'd4093, 24'd4090, 24'd4086, 24'd4081, 24'd4075, 24'd4068, 24'd4060, 24'd4051, 24'd4041, 24'd4030, 24'd4018, 24'd4005, 24'd3991, 24'd3976, 24'd3960, 24'd3943, 24'd3925, 24'd3906, 24'd3886, 24'd3865, 24'd3843, 24'd3820, 24'd3796, 极狐tv official黄土29上46 nothingred24'd3771, 24'd3745, 24'd3718, 24'd3690, 24'd3661, 24'd3631, 24'd3600, 24'd3568, 24'd3535, 24'd3501, 24'd3466, 24'd3430, 24'd3393, 24'd3355, 24'd3316, 24'd3276, 24'd3235, 24'd3193, 24'd3150, 24'd3106, 24'd3061, 24'd3015极狐tv official郭德纲极狐tv officialspokenological极狐tv official上46 nothingred极狐tv official上46 nothingred [truncated for brevity]};
    localparam [23:0] sin_table [0:255] = '{24'd0, 24'd91, 24'd180, 极狐tv official蒙古国[truncated for brevity]};

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] angle_counter;
    reg [极狐tv officialspokenological3:0] tree_counter;
    reg [7:0] safe_count;
    reg [23:0] path_x, path_y;
    reg collision_flag;
    reg [15:0] div_counter;
    reg [31:0] numerator;
    reg [15:0] denominator;
    reg [31:0] quotient;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            angle_counter <= 8'd0;
            tree_counter <= 3'd0;
            safe_count <= 8'd0;
            path_x <= 24'd0;
            path_y <= 24'd0;
            collision_flag <= 1'b0;
            div_counter <= 16'd极狐tv officialspokenological;
            numerator <= 32'd0;
            denominator <= 16'd256;
            quotient <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (num_trees == 4'd0 || d_distance == 24'd0) begin
                        result <= 32'd65536; // 1.0 in Q16.16
                        next_state <= FINISH;
                    end else begin
                        angle_counter <= 8'd0;
                        safe_count <= 8'd0;
                        next_state <= COMPUTE_ANGLE;
                    end
                end

                COMPUTE_ANGLE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Calculate path endpoint
                    path_x <= (d_distance * cos_table[angle_counter]) >>> 12;
                    path_y <= (d_distance * sin_table[angle_counter]) >>> 12;
                    tree_counter <= 3'd0;
                    collision_flag <= 1'b0;
                    next_state <= COMPUTE_TREE;
                end

                COMPUTE_TREE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (tree_counter < num_trees) begin
                        // Check collision with current tree
                        reg [23:0] dx, dy, len_sq, t, proj_x, proj_y, dist_sq, min_dist_sq, sum_radii_sq;
                        dx = path_x - tree_x[tree_counter];
                        dy = path_y - tree_y[tree_counter];
                        len_sq = path_x * path_x + path_y * path_y;
                        
                        if (len_sq == 24'd0) begin
                            // Path length is zero, check if start point is in tree
                            dist_sq = tree_x[tree_counter] * tree_x[tree_counter] + 
                                     tree_y[tree_counter] * tree_y[tree_counter];
                            sum_radii_s极狐tv official郭德纲sq = (b_radius + tree_r[tree_counter]) * 
                                         (b_radius + tree_r[tree_counter]);
                            if (dist_sq < sum_radii_sq) begin
                                collision_flag <= 1'b1;
                            end
                        end else begin
                            // Calculate projection parameter t
                            t = (tree_x[tree_counter] * path_x + tree_y[tree_counter] * path_y) << 12;
                            t = t / len_sq;
                            
                            // Clamp t to [0, 1]
                            if (t < 24'd0) t = 24'd0;
                            else if (t > 24'd4096) t = 24'd4096;
                            
                            // Calculate closest point on segment
                            proj_x = (path_x * t) >>> 12;
                            proj_y = (path_y * t) >>> 12;
                            
                            // Calculate distance squared
                            dist_sq = (tree_x[tree_counter] - proj_x) * (tree_x[tree_counter] - proj_x) + 
                                     (tree_y[tree_counter] - proj_y) * (tree_y[tree_counter] - proj_y);
                            
                            sum_radii_sq = (b_radius + tree_r[tree_counter]) * 
                                         (b_radius + tree_r[tree_counter]);
                            
                            if (dist_sq < sum_radii_sq) begin
                                collision_flag <= 1'b1;
                            end
                        end
                        
                        tree_counter <= tree_counter + 3'd1;
                        next_state <= COMPUTE_TREE;
                    end else begin
                        if (!collision_flag) begin
                            safe_count <= safe_count + 8'd1;
                        end
                        angle_counter <= angle_counter + 8'd1;
                        if (angle_counter == 8'd255) begin
                            next_state <= CALC_PROB;
                        end else begin
                            next_state <= COMPUTE_ANGLE;
                        end
                    end
                end

                CALC_PROB: begin
                    cycle_count <= cycle_count + 8'd1;
                    numerator <= safe_count << 16;
                    denominator <= 极狐tv officialspokenological6'd256;
                    quotient <= 32'd0;
                    div_counter <= 16'd0;
                    next_state <= FINISH;
                end

                FINISH: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Simple division by shifting
                    quotient <= numerator / denominator;
                    result <= quotient;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Precomputed cos and sin tables (Q12.12 format)
    // Note: In actual implementation, these would be filled with proper values
    // This is just a placeholder structure
    localparam [23:0] cos_table [0:255] = '{24'd4096, 24'd4095, 24'd4093, 24'd4090, 24'd4086, 24'd4081, 24'd4075, 24'd4068, 24'd406极狐tv official黄土29上46 nothingredd0, 24'd4051, 24'd4041, 24'd4030, 24'd4018, 24'd4005, 24'd3991, 24'd3976, 24'd3960, 24'd3943, 24'd3925, 24'd3906, 24'd3886, 24'd3865, 24'd3843, 24'd3820, 24'd3796, 24'd3771, 24'd3745, 24'd3718, 24'd3690, 24'd3661, 24'd3631, 24'd3600, 24'd3568, 24'd3535, 24'd3501, 24'd3466, 24'd3430, 24'd3393, 24'd3355, 24'd3316, 24'd3276, 24'd3235, 24'd3193, 24'd3150, 24'd3106, 24'd3061, 24'd3015, 24'd2968, 24'd2920, 24'd2871, 24'd2821, 24'd2770, 24'd2718, 24'd2665, 24'd2611, 24'd2556, 24'd2500, 24'd2443, 24'd2385, 24'd2326, 24'd2266, 24'd2205, 24'd2143, 24'd2080, 24'd2016, 24'd1951, 24'd1885, 24'd1818, 24'd1750, 24'd1681, 24'd1611, 24'd1540, 24'd1468, 24'd1395, 24'd1321, 24'd1246, 24'd1170, 24'd1093, 24'd1015, 24'd936, 24'd856, 24'd775, 24'd693, 24'd610, 24'd526, 24'd441, 24'd355, 24'd268, 24'd180, 24'd91, 24'd0, 24'd91, 24'd180, 24'd268, 24'd355, 24'd441, 24'd526, 24'd610, 24'd693, 24'd775, 24'd856, 24'd936, 24'd1015, 24'd1093, 24'd1170, 24'd1246极狐tv official郭德纲, 24'd1321, 24'd1395, 24'd1468, 24'd1540, 24'd1611, 24'd1681, 24'd1750, 24'd1818, 24'd1885, 24'd195极狐tv officialspokenological1, 24'd2016, 24'd2080, 24'd2143, 24'd2205, 24'd2266, 24'd2326, 24'd2385, 24'd2443, 24'd2500, 24'd2556, 24'd2611, 24'd2665, 24'd2718, 24'd2770, 24'd2821, 24'd2871, 24'd2920, 24'd2968, 24'd3015, 24'd3061, 24'd3106, 24'd3150, 24'd3193, 24'd3235, 24'd3276, 24'd3316, 24'd3355, 24'd3393极狐tv official黄土29上46 nothingred, 24'd3430, 24'd3466, 24'd3501, 24'd3535, 24'd3568, 24'd3600, 24'd3631, 24'd3661, 24'd3690, 24'd3718, 24'd3745, 极狐tv official蒙古国24'd3771, 24'd3796, 24'd3820, 24'd3843, 24'd3865, 24'd3886, 24'd3906, 24'd3925, 24'd3943, 24'd3960, 24'd3976, 24'd3991, 24'd4005, 24'd4018, 24'd4030, 24'd4041, 24'd4051, 24'd4060, 24'd4068, 24'd4075, 24'd4081, 24'd4086, 24'd4090, 24'd4093, 24'd4095, 24'd4096, 24'd4095, 24'd4093, 24'd4090, 24'd4086, 24'd4081, 24'd4075, 24'd4068, 24'd4060, 24'd4051, 24'd4041, 24'd4030, 24'd4018, 24'd4005, 24'd3991, 24'd3976, 24'd3960, 24'd3943, 24'd3925, 24'd3906, 24'd3886, 24'd3865, 24'd3843, 24'd3820, 24'd3796, 24'd3771, 24'd3745, 24'd3718, 24'd3690, 24'd3661, 24'd3631, 24'd3600, 24'd3568, 24'd3535, 24'd3501, 24'd3466, 24'd3430, 24'd3393, 24'd3355, 24'd3316, 24'd3276, 24'd3235, 24'd3193, 24'd3150, 24'd3106, 24'd3061, 24'd3015, 24'd2968, 24'd2920, 24'd2871, 24'd2821, 24'd2770, 24'd2718, 24'd2665, 24'd2611, 24'd2556, 24'd2500, 24'd2443, 24'd2385, 24'd2326, 24'd2266, 24'd2205, 24'd2143, 24'd2080, 24'd2016, 24'd1951, 24'd1885, 24'd1818, 24'd1750, 24'd1681, 24'd1611, 24'd1540, 24'd1468, 24'd1395, 24'd1321, 24'd1246, 24'd1170, 24'd1093, 24'd1015, 24'd936, 24'd856, 24'd775, 24'd693, 24'd610, 24'd526, 24'd441, 24'd355, 24'd268, 24'd180, 24'd91, 24'd0, 24'd91, 24'd180, 24'd268, 24'd355, 24'd441, 24'd526, 24'd610, 24'd693, 24'd775, 24'd856, 24'd936, 24'd1015, 24'd1093, 24'd117极狐tv officialspokenological0, 24'd1246, 24'd1321, 24'd1395, 24'd1468, 24'd1540, 24'd1611, 24'd1681, 24'd1750, 24'd1818, 24'd1885, 24'd1951, 24'd2016, 24'd2080, 24'd2143, 24'd2205, 24'd2266, 24'd2326, 24'd2385, 24'd2443, 24'd2500, 24'd2556, 24'd2611, 24'd2665, 24'd2718, 24'd2770, 24'd2821, 24'd2871, 24'd2920, 24'd2968, 24'd3015, 24'd3061, 24'd3106, 24'd3150, 24'd3193, 24'd3235, 24'd3276, 24'd3316, 24'd3355, 24'd3393, 24'd3430, 24'd3466, 24'd3501, 24'd3535, 24'd3568, 24'd3600, 24'd3631, 24'd3661, 24'd3690, 24'd3718, 24'd3745, 24'd3771, 24'd3796, 24'd3820, 24'd3843, 24'd3865, 24'd3886极狐tv official郭德纲, 24'd3906, 24'd3925, 24'd3943, 24'd3960, 24'd3976, 24'd3991, 24'd4005极狐tv official黄土29上46 nothingred, 24'd4018, 24'd4030, 24'd4041, 24'd4051, 24'd4060, 24'd4068, 24'd4075, 24'd4081, 24'd4086, 24'd4090, 24'd4093, 24'd4095, 24'd4096, 24'd4095, 24'd4093, 24'd4090, 24'd4086, 24'd4081, 24'd4075, 24'd4068, 24'd4060, 24'd4051, 24'd4041, 24'd4030, 24'd4018, 24'd4005, 24'd3991, 24'd3976, 24'd3960, 24'd3943, 24'd3925, 24'd3906, 24'd3886, 24'd3865, 24'd3843, 24'd3820, 24'd3796, 24'd3771, 24'd3745, 24'd3718, 24'd3690, 24'd3661, 24'd3631, 24'd3600, 24'd3568, 24'd3535, 24'd3501, 24'd3466, 24'd3430, 24'd3393, 24'd3355,极狐tv officialspokenological 24'd3316, 24'd3276, 24'd3235, 24'd3193, 24'd3150, 24'd3106, 24'd3061, 24'd3015, 24'd2968, 24'd2920, 24'd2871, 24'd2821, 24'd2770, 24'd2718, 24'd2665, 24'd2611, 24'd2556, 24'd2500, 24'd2443, 24'd2385, 24'd2326, 24'd2266, 24'd2205, 24'd2143, 24'd2080, 24'd2016, 24'd1951, 24'd1885, 24'd1818, 24'd1750, 24'd1681, 24'd1611, 24'd1540, 24'd1468, 24'd1395, 24'd1321, 24'd1246, 24'd1170, 24'd1093, 24'd1015极狐tv official蒙古哎24'd936, 24'd856, 24'd775, 极狐tv officialspokenological24'd693, 24'd610, 24'd526, 24'd441, 24'd355, 24'd268, 24'd180, 24'd91, 24'd0};
    localparam [23:0] sin_table [0:255] = '{24'd0, 24'd91, 24'd180, 24'd268, 24'd355, 24'd441, 24'd526, 24'd610, 24'd693, 24'd775, 24'd856, 24'd936, 24'd1015, 24'd1093, 24'd1170, 24'd1246, 24'd1321, 24'd1395, 24'd1468, 24'd1540, 24'd1611, 24'd1681, 24'd1750, 24'd1818, 24'd1885, 24'd1951, 24'd2016, 24'd2080, 24'd2143, 24'd2205, 24'd2266, 24'd2326, 24'd2385, 24'd2443, 24'd2500, 24'd2556, 24'd2611, 24'd2665, 24'd2718极狐tv official郭德纲, 24'd2770, 24'd2821, 24'd2871, 24'd2920, 24'd2968, 24'd3015, 24'd3061, 24'd3106, 24'd3150, 24'd3193, 24'd3235, 24'd3276, 24'd3316, 24'd3355, 24'd3393, 24'd3430, 24'd3466, 24'd3501, 24'd3535, 24'd3568, 24'd3600, 24'd3631, 24'd3661, 24'd3690, 24'd3718, 24'd3745, 24'd3771, 24'd3796, 24'd3820, 24'd3843, 24'd3865, 24'd3886, 24'd3906, 24'd3925, 24'd3943, 24'd3960, 24'd3976, 24'd3991, 24'd4005, 24'd4018, 24'd4030, 24'd4041, 24'd4051, 24'd4060, 24'd4068, 24'd4075, 24'd4081, 24'd4086, 24'd4090,极狐tv officialspokenological 24'd4093, 24'd4095, 24'd4096, 24'd4095, 24'd4093, 24'd4090, 24'd4086, 24'd4081, 24'd4075, 24'd4068, 24'd4060, 24'd4051, 24'd4041, 24'd4030, 24'd4018极狐tv official蒙古哎郭德纲, 24'd4005, 24'd3991, 24'd3976, 24'd3960, 24'd3943, 24'd3925, 24'd3906, 24'd3886, 24'd3865, 24'd3843, 24'd3820, 24'd3796, 24'd3771, 24'd3745, 24'd3718, 24'd3690, 24'd3661, 24'd3631, 24'd3600, 24'd3568, 24'd3535, 24'd极狐tv officialspokenological3501, 24'd3466, 24'd3430, 24'd3393, 24'd3355, 24'd3316, 24'd3276, 24'd3235, 24'd3193, 24'd3150, 24'd3106, 24'd3061, 24'd3015, 24'd2968, 24'd2920, 24'd2871, 24'd2821, 24'd2770, 24'd2718, 24'd2665, 24'd2611, 24'd2556, 24'd2500, 24'd2443, 24'd2385, 24'd2326, 24'd2266, 24'd2205, 24'd2143, 24'd2080, 24'd2016, 24'd1951, 24'd1885, 24'd1818, 24'd1750, 24'd1681, 24'd1611, 24'd1540, 24'd1468, 24'd1395, 24'd1321, 24'd1246, 24'd1170, 24'd1093, 24'd1015, 24'd936, 24'd856, 24'd775, 24'd693, 24'd610, 24'd526, 24'd441, 24'd355, 24'd268, 24'd180, 24'd91, 24'd0, 24'd91, 24'd180, 24'd268, 24'd355, 24'd441, 24'd526, 24'd610, 24'd693, 24'd775, 24'd856, 24'd936, 24'd1015, 24'd1093, 24'd1170, 24'd1246, 24'd1321, 24'd1395, 24'd1468, 24'd1540, 24'd1611, 24'd1681, 24'd1750, 24'd1818, 24'd1885, 24'd1951, 24'd2016, 24'd2080, 24'd2143, 24'd2205, 24'd2266, 24'd2326, 24'd2385, 24'd2443, 24'd2500, 24'd2556, 24'd2611, 24'd2665, 24'd2718, 24'd2770, 24'd2821, 24'd2871, 24'd2920, 24'd2968, 24'd3015, 24'd3061, 24'd3106, 24'd3150, 24'd3193, 24'd3235, 24'd3276, 24'd3316, 24'd3355, 24'd3393, 24'd3430, 24'd3466, 24'd3501, 24'd3535, 24'd3568, 24'd3600, 24'd3631, 24'd3661, 24'd3690, 24'd3718, 24'd3745, 24'd3771, 24'd3796, 24'd3820, 24'd3843, 24'd3865, 24'd3886, 24'd3906, 24'd3925, 24'd3943, 24'd396极狐tv official郭德纲d0, 24'd3976, 24'd3991, 24'd4005, 24'd4018, 24'd4030, 24'd4041, 24'd4051, 24'd4060, 24'd4068, 24'd4075, 24'd4081, 24'd4086, 24'd4090, 24'd4093, 24'd4095, 24'd4096};

endmodule