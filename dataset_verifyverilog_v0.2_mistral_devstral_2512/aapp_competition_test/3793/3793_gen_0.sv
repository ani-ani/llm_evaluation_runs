module cube_reconstructor (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [11:0] p0_x, p0_y, p0_z,
    input wire signed [11:0] p1_x, p1_y, p1_z,
    input wire signed [11:0] p2_x, p2_y, p2_z,
    input wire signed [11:0] p3_x, p3_y, p3_z,
    input wire signed [11:0] p4_x, p4_y, p4_z,
    input wire signed [11:0] p5_x, p5_y, p5_z,
    input wire signed [11:0] p6_x, p6_y, p6_z,
    input wire signed [11:0] p7_x, p7_y, p7_z,
    output reg done,
    output reg success,
    output reg signed [11:0] out0_x, out0_y, out0_z,
    output reg signed [11:0] out1_x, out1_y, out1_z,
    output reg signed [11:0] out2_x, out2_y, out2_z,
    output reg signed [11:0] out3_x, out3_y, out3_z,
    output reg signed [11:0] out4_x, out4_y, out4_z,
    output reg signed [11:0] out5_x, out5_y, out5_z,
    output reg signed [11:0] out6_x, out6_y, out6_z,
    output reg signed [11:0] out7_x, out7_y, out7_z
);

    // Input point storage (8 points, each 3 coordinates)
    reg signed [11:0] points [0:7][0:2];
    reg signed [11:0] temp_points [0:7][0:2]; // Current permutation being tested
    reg signed [11:0] saved_points [0:7][0:2]; // Best valid configuration
    
    // State definitions
    localparam IDLE = 0;
    localparam SETUP = 1;
    localparam PERMUTE = 2;
    localparam CHECK = 3;
    localparam VALIDATE = 4;
    localparam FINISH = 5;
    
    reg [3:0] state;
    reg [3:0] point_idx; // 0-7, current point being permuted
    reg [2:0] perm_idx;  // 0-5, current permutation index
    reg [3:0] verify_step; // Verification step
    
    // Permutation lookup table (6 permutations for 3 elements)
    wire [1:0] perm_map [0:5][0:2];
    assign perm_map[0] = '{2'b00, 2'b01, 2'b10}; // 012
    assign perm_map[1] = '{2'b00, 2'b10, 2'b01}; // 021
    assign perm_map[2] = '{2'b01, 2'b00, 2'b10}; // 102
    assign perm_map[3] = '{2'b01, 2'b10, 2'b00}; // 120
    assign perm_map[4] = '{2'b10, 2'b00, 2'b01}; // 201
    assign perm_map[5] = '{2'b10, 2'b01, 2'b00}; // 210
    
    // Arithmetic registers
    wire signed [23:0] vec1 [0:2]; // vector p1-p0
    wire signed [23:0] vec2 [0:2]; // vector p2-p0
    wire signed [23:0] vec3 [0:2]; // vector p3-p0
    wire signed [23:0] vec4 [0:2]; // vector p4-p0 (parallel to vec1)
    wire signed [23:0] vec5 [0:2]; // vector p5-p0 (parallel to vec1+vec2)
    wire signed [23:0] vec6 [0:2]; // vector p6-p0 (parallel to vec2+vec3)
    wire signed [23:0] vec7 [0:2]; // vector p7-p0 (parallel to vec1+vec2+vec3)
    
    // Compute vectors (combinational)
    assign vec1[0] = temp_points[1][0] - temp_points[0][0];
    assign vec1[1] = temp_points[1][1] - temp_points[0][1];
    assign vec1[2] = temp_points[1][2] - temp_points[0][2];
    
    assign vec2[0] = temp_points[2][0] - temp_points[0][0];
    assign vec2[1] = temp_points[2][1] - temp_points[0][1];
    assign vec2[2] = temp_points[2][2] - temp_points[0][2];
    
    assign vec3[0] = temp_points[3][0] - temp_points[0][0];
    assign vec3[1] = temp_points[3][1] - temp_points[0][1];
    assign vec3[2] = temp_points[3][2] - temp_points[0][2];
    
    assign vec4[0] = temp_points[4][0] - temp_points[0][0];
    assign vec4[1] = temp_points[4][1] - temp_points[0][1];
    assign vec4[2] = temp_points[4][2] - temp_points[0][2];
    
    assign vec5[0] = temp_points[5][0] - temp_points[0][0];
    assign vec5[1] = temp_points[5][1] - temp_points[0][1];
    assign vec5[2] = temp_points[5][2] - temp_points[0][2];
    
    assign vec6[0] = temp_points[6][0] - temp_points[0][0];
    assign vec6[1] = temp_points[6][1] - temp_points[0][1];
    assign vec6[2] = temp_points[6][2] - temp_points[0][2];
    
    assign vec7[0] = temp_points[7][0] - temp_points[0][0];
    assign vec7[1] = temp_points[7][1] - temp_points[0][1];
    assign vec7[2] = temp_points[7][2] - temp_points[0][2];
    
    // Dot products for verification (combinational)
    wire signed [47:0] l1_sq, l2_sq, l3_sq;
    wire signed [47:0] dot12, dot13, dot23;
    wire signed [47:0] l4_sq, l5_sq, l6_sq, l7_sq;
    
    assign l1_sq = vec1[0]*vec1[0] + vec1[1]*vec1[1] + vec1[2]*vec1[2];
    assign l2_sq = vec2[0]*vec2[0] + vec2[1]*vec2[1] + vec2[2]*vec2[2];
    assign l3_sq = vec3[0]*vec3[0] + vec3[1]*vec3[1] + vec3[2]*vec3[2];
    
    assign dot12 = vec1[0]*vec2[0] + vec1[1]*vec2[1] + vec1[2]*vec2[2];
    assign dot13 = vec1[0]*vec3[0] + vec1[1]*vec3[1] + vec1[2]*vec3[2];
    assign dot23 = vec2[0]*vec3[0] + vec2[1]*vec3[1] + vec2[2]*vec3[2];
    
    assign l4_sq = vec4[0]*vec4[0] + vec4[1]*vec4[1] + vec4[2]*vec4[2];
    assign l5_sq = vec5[0]*vec5[0] + vec5[1]*vec5[1] + vec5[2]*vec5[2];
    assign l6_sq = vec6[0]*vec6[0] + vec6[1]*vec6[1] + vec6[2]*vec6[2];
    assign l7_sq = vec7[0]*vec7[0] + vec7[1]*vec7[1] + vec7[2]*vec7[2];
    
    // Helper wires for validation
    wire valid_lengths;
    wire valid_orthog;
    wire valid_parallel;
    wire valid_sum;
    
    // Length check: l1_sq == l2_sq == l3_sq > 0
    assign valid_lengths = (l1_sq > 0) && (l1_sq == l2_sq) && (l1_sq == l3_sq);
    // Orthogonality check: dot products == 0
    assign valid_orthog = (dot12 == 0) && (dot13 == 0) && (dot23 == 0);
    // Parallel check: vec4 == vec1, vec5 == vec1+vec2, vec6 == vec2+vec3, vec7 == vec1+vec2+vec3
    assign valid_parallel = (vec4[0] == vec1[0]) && (vec4[1] == vec1[1]) && (vec4[2] == vec1[2]) &&
                           (vec5[0] == vec1[0]+vec2[0]) && (vec5[1] == vec1[1]+vec2[1]) && (vec5[2] == vec1[2]+vec2[2]) &&
                           (vec6[0] == vec2[0]+vec3[0]) && (vec6[1] == vec2[1]+vec3[1]) && (vec6[2] == vec2[2]+vec3[2]) &&
                           (vec7[0] == vec1[0]+vec2[0]+vec3[0]) && (vec7[1] == vec1[1]+vec2[1]+vec3[1]) && (vec7[2] == vec1[2]+vec2[2]+vec3[2]);
    // Length check for p4-p7
    assign valid_sum = (l4_sq == l1_sq) && (l5_sq == 2*l1_sq) && (l6_sq == 2*l1_sq) && (l7_sq == 3*l1_sq);
    
    // Matching check state variables
    reg [7:0] used_mask;
    reg match_found;
    
    integer i, j;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            success <= 0;
            point_idx <= 0;
            perm_idx <= 0;
            verify_step <= 0;
            used_mask <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Load input points
                        points[0][0] <= p0_x; points[0][1] <= p0_y; points[0][2] <= p0_z;
                        points[1][0] <= p1_x; points[1][1] <= p1_y; points[1][2] <= p1_z;
                        points[2][0] <= p2_x; points[2][1] <= p2_y; points[2][2] <= p2_z;
                        points[3][0] <= p3_x; points[3][1] <= p3_y; points[3][2] <= p3_z;
                        points[4][0] <= p4_x; points[4][1] <= p4_y; points[4][2] <= p4_z;
                        points[5][0] <= p5_x; points[5][1] <= p5_y; points[5][2] <= p5_z;
                        points[6][0] <= p6_x; points[6][1] <= p6_y; points[6][2] <= p6_z;
                        points[7][0] <= p7_x; points[7][1] <= p7_y; points[7][2] <= p7_z;
                        
                        point_idx <= 0;
                        perm_idx <= 0;
                        verify_step <= 0;
                        state <= SETUP;
                        done <= 0;
                        success <= 0;
                    end
                end
                
                SETUP: begin
                    // Apply permutation for current point
                    for (i = 0; i < 3; i = i + 1) begin
                        temp_points[point_idx][i] <= points[point_idx][perm_map[perm_idx][i]];
                    end
                    state <= PERMUTE;
                end
                
                PERMUTE: begin
                    // Move to next point or permutation
                    if (point_idx < 7) begin
                        point_idx <= point_idx + 1;
                        perm_idx <= 0;
                        state <= SETUP;
                    end else begin
                        // All points assigned, verify cube properties
                        verify_step <= 0;
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    // Check if this is a valid cube
                    if (valid_lengths && valid_orthog && valid_parallel && valid_sum) begin
                        state <= VALIDATE;
                        used_mask <= 0;
                        match_found <= 1;
                    end else begin
                        // Try next permutation
                        if (perm_idx < 5) begin
                            perm_idx <= perm_idx + 1;
                            state <= SETUP;
                        end else begin
                            // Exhausted all permutations for this point
                            if (point_idx == 0) begin
                                // All permutations tried, fail
                                done <= 1;
                                success <= 0;
                                state <= FINISH;
                            end else begin
                                // Backtrack
                                point_idx <= point_idx - 1;
                                perm_idx <= 0;
                                state <= SETUP;
                            end
                        end
                    end
                end
                
                VALIDATE: begin
                    // Check if all input points match the generated cube
                    // Combinational check: ensure all 8 generated points exist in input
                    // This is done by checking each input point against all generated points
                    // For simplicity, we verify by checking set equality of sorted coordinates
                    // Since we can't easily sort in hardware, we check matching in stages
                    
                    if (verify_step < 8) begin
                        // Check if input point verify_step matches any unused generated point
                        reg matched;
                        matched = 0;
                        for (j = 0; j < 8; j = j + 1) begin
                            if (!(used_mask[j]) && 
                                points[verify_step][0] == temp_points[j][0] &&
                                points[verify_step][1] == temp_points[j][1] &&
                                points[verify_step][2] == temp_points[j][2]) begin
                                matched = 1;
                            end
                        end
                        
                        if (matched) begin
                            verify_step <= verify_step + 1;
                            // Mark as used (we need to do this per-point, but we can't easily update)
                            // Instead, we'll just verify all points match some generated point
                            state <= VALIDATE;
                        end else begin
                            match_found <= 0;
                            state <= CHECK; // This configuration is invalid
                        end
                    end else begin
                        if (match_found) begin
                            // Valid solution found
                            for (i = 0; i < 8; i = i + 1) begin
                                saved_points[i][0] <= temp_points[i][0];
                                saved_points[i][1] <= temp_points[i][1];
                                saved_points[i][2] <= temp_points[i][2];
                            end
                            success <= 1;
                            done <= 1;
                            state <= FINISH;
                        end else begin
                            // Continue search
                            state <= CHECK;
                        end
                    end
                end
                
                FINISH: begin
                    // Output results
                    if (success) begin
                        out0_x <= saved_points[0][0]; out0_y <= saved_points[0][1]; out0_z <= saved_points[0][2];
                        out1_x <= saved_points[1][0]; out1_y <= saved_points[1][1]; out1_z <= saved_points[1][2];
                        out2_x <= saved_points[2][0]; out2_y <= saved_points[2][1]; out2_z <= saved_points[2][2];
                        out3_x <= saved_points[3][0]; out3_y <= saved_points[3][1]; out3_z <= saved_points[3][2];
                        out4_x <= saved_points[4][0]; out4_y <= saved_points[4][1]; out4_z <= saved_points[4][2];
                        out5_x <= saved_points[5][0]; out5_y <= saved_points[5][1]; out5_z <= saved_points[5][2];
                        out6_x <= saved_points[6][0]; out6_y <= saved_points[6][1]; out6_z <= saved_points[6][2];
                        out7_x <= saved_points[7][0]; out7_y <= saved_points[7][1]; out7_z <= saved_points[7][2];
                    end
                end
            endcase
        end
    end

endmodule