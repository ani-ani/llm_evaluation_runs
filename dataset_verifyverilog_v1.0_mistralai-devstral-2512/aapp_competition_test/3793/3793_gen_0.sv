module CubeReconstructor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [31:0] v0_x, v0_y, v0_z,
    input wire signed [31:0] v1_x, v1_y, v1_z,
    input wire signed [31:0] v2_x, v2_y, v2_z,
    input wire signed [31:0] v3_x, v3_y, v3_z,
    input wire signed [31:0] v4_x, v4_y, v4_z,
    input wire signed [31:0] v5_x, v5_y, v5_z,
    input wire signed [31:0] v6_x, v6_y, v6_z,
    input wire signed [31:0] v7_x, v7_y, v7_z,
    output reg signed [31:0] out_v0_x, out_v0_y, out_v0_z,
    output reg signed [31:0] out_v1_x, out_v1_y, out_v1_z,
    output reg signed [31:0] out_v2_x, out_v2_y, out_v2_z,
    output reg signed [31:0] out_v3_x, out_v3_y, out_v3_z,
    output reg signed [31:0] out_v4_x, out_v4_y, out_v4_z,
    output reg signed [31:0] out_v5_x, out_v5_y, out_v5_z,
    output reg signed [31:0] out_v6_x, out_v6_y, out_v6_z,
    output reg signed [31:0] out_v7_x, out_v7_y, out_v7_z,
    output reg valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] SEARCH = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Permutation LUT (6 permutations per vertex)
    localparam [2:0] PERM_0 = 3'd0; // x,y,z
    localparam [2:0] PERM_1 = 3'd1; // x,z,y
    localparam [2:0] PERM_2 = 3'd2; // y,x,z
    localparam [2:0] PERM_3 = 3'd3; // y,z,x
    localparam [2:0] PERM_4 = 3'd4; // z,x,y
    localparam [2:0] PERM_5 = 3'd5; // z,y,x

    // Input storage registers
    reg signed [31:0] v0[0:2], v1[0:2], v2[0:2], v3[0:2], v4[0:2], v5[0:2], v6[0:2], v7[0:2];

    // Permutation counters (8 vertices, each with 6 permutations)
    reg [2:0] perm0, perm1, perm2, perm3, perm4, perm5, perm6, perm7;

    // Current vertex coordinates after permutation
    reg signed [31:0] cv0[0:2], cv1[0:2], cv2[0:2], cv3[0:2], cv4[0:2], cv5[0:2], cv6[0:2], cv7[0:2];

    // Distance calculation
    reg [63:0] dist[0:27]; // 28 pairwise distances (8 vertices)
    reg [63:0] dist_sq[0:27];

    // Distance analysis
    reg [63:0] min_dist;
    reg [63:0] edge_sq, face_diag_sq, space_diag_sq;
    reg [3:0] edge_count, face_diag_count, space_diag_count;

    // State and control
    reg [2:0] state;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // Permutation application function
    function [31:0] apply_perm;
        input [31:0] x, y, z;
        input [2:0] perm;
        case (perm)
            PERM_0: apply_perm = x;
            PERM_1: apply_perm = x;
            PERM_2: apply_perm = y;
            PERM_3: apply_perm = y;
            PERM_4: apply_perm = z;
            PERM_5: apply_perm = z;
            default: apply_perm = x;
        endcase
    endfunction

    function [31:0] apply_perm_y;
        input [31:0] x, y, z;
        input [2:0] perm;
        case (perm)
            PERM_0: apply_perm_y = y;
            PERM_1: apply_perm_y = z;
            PERM_2: apply_perm_y = x;
            PERM_3: apply_perm_y = z;
            PERM_4: apply_perm_y = x;
            PERM_5: apply_perm_y = y;
            default: apply_perm_y = y;
        endcase
    endfunction

    function [31:0] apply_perm_z;
        input [31:0] x, y, z;
        input [2:0] perm;
        case (perm)
            PERM_0: apply_perm_z = z;
            PERM_1: apply_perm_z = y;
            PERM_2: apply_perm_z = z;
            PERM_3: apply_perm_z = x;
            PERM_4: apply_perm_z = y;
            PERM_5: apply_perm_z = x;
            default: apply_perm_z = z;
        endcase
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 16'd0;

            // Initialize all outputs
            out_v0_x <= 32'd0; out_v0_y <= 32'd0; out_v0_z <= 32'd0;
            out_v1_x <= 32'd0; out_v1_y <= 32'd0; out_v1_z <= 32'd0;
            out_v2_x <= 32'd0; out_v2_y <= 32'd0; out_v2_z <= 32'd0;
            out_v3_x <= 32'd0; out_v3_y <= 32'd0; out_v3_z <= 32'd0;
            out_v4_x <= 32'd0; out_v4_y <= 32'd0; out_v4_z <= 32'd0;
            out_v5_x <= 32'd0; out_v5_y <= 32'd0; out_v5_z <= 32'd0;
            out_v6_x <= 32'd0; out_v6_y <= 32'd0; out_v6_z <= 32'd0;
            out_v7_x <= 32'd0; out_v7_y <= 32'd0; out_v7_z <= 32'd0;

            // Initialize permutation counters
            perm0 <= 3'd0; perm1 <= 3'd0; perm2 <= 3'd0; perm3 <= 3'd0;
            perm4 <= 3'd0; perm5 <= 3'd0; perm6 <= 3'd0; perm7 <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Store input vertices
                    v0[0] <= v0_x; v0[1] <= v0_y; v0[2] <= v0_z;
                    v1[0] <= v1_x; v1[1] <= v1_y; v1[2] <= v1_z;
                    v2[0] <= v2_x; v2[1] <= v2_y; v2[2] <= v2_z;
                    v3[0] <= v3_x; v3[1] <= v3_y; v3[2] <= v3_z;
                    v4[0] <= v4_x; v4[1] <= v4_y; v4[2] <= v4_z;
                    v5[0] <= v5_x; v5[1] <= v5_y; v5[2] <= v5_z;
                    v6[0] <= v6_x; v6[1] <= v6_y; v6[2] <= v6_z;
                    v7[0] <= v7_x; v7[1] <= v7_y; v7[2] <= v7_z;

                    // Initialize permutation counters
                    perm0 <= 3'd0; perm1 <= 3'd0; perm2 <= 3'd0; perm3 <= 3'd0;
                    perm4 <= 3'd0; perm5 <= 3'd0; perm6 <= 3'd0; perm7 <= 3'd0;

                    state <= SEARCH;
                end

                SEARCH: begin
                    cycle_count <= cycle_count + 16'd1;

                    // Apply current permutations to get current vertices
                    cv0[0] = apply_perm(v0[0], v0[1], v0[2], perm0);
                    cv0[1] = apply_perm_y(v0[0], v0[1], v0[2], perm0);
                    cv0[2] = apply_perm_z(v0[0], v0[1], v0[2], perm0);

                    cv1[0] = apply_perm(v1[0], v1[1], v1[2], perm1);
                    cv1[1] = apply_perm_y(v1[0], v1[1], v1[2], perm1);
                    cv1[2] = apply_perm_z(v1[0], v1[1], v1[2], perm1);

                    cv2[0] = apply_perm(v2[0], v2[1], v2[2], perm2);
                    cv2[1] = apply_perm_y(v2[0], v2[1], v2[2], perm2);
                    cv2[2] = apply_perm_z(v2[0], v2[1], v2[2], perm2);

                    cv3[0] = apply_perm(v3[0], v3[1], v3[2], perm3);
                    cv3[1] = apply_perm_y(v3[0], v3[1], v3[2], perm3);
                    cv3[2] = apply_perm_z(v3[0], v3[1], v3[2], perm3);

                    cv4[0] = apply_perm(v4[0], v4[1], v4[2], perm4);
                    cv4[1] = apply_perm_y(v4[0], v4[1], v4[2], perm4);
                    cv4[2] = apply_perm_z(v4[0], v4[1], v4[2], perm4);

                    cv5[0] = apply_perm(v5[0], v5[1], v5[2], perm5);
                    cv5[1] = apply_perm_y(v5[0], v5[1], v5[2], perm5);
                    cv5[2] = apply_perm_z(v5[0], v5[1], v5[2], perm5);

                    cv6[0] = apply_perm(v6[0], v6[1], v6[2], perm6);
                    cv6[1] = apply_perm_y(v6[0], v6[1], v6[2], perm6);
                    cv6[2] = apply_perm_z(v6[0], v6[1], v6[2], perm6);

                    cv7[0] = apply_perm(v7[0], v7[1], v7[2], perm7);
                    cv7[1] = apply_perm_y(v7[0], v7[1], v7[2], perm7);
                    cv7[2] = apply_perm_z(v7[0], v7[1], v7[2], perm7);

                    // Calculate all pairwise squared distances
                    integer i, j, k;
                    k = 0;
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = i + 1; j < 8; j = j + 1) begin
                            case (i)
                                0: begin
                                    case (j)
                                        1: begin
                                            dist[k] = (cv0[0] - cv1[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv0[1] - cv1[1])*(cv0[1] - cv1[1])) + 
                                                        ((cv0[2] - cv1[2])*(cv0[2] - cv1[2]));
                                        end
                                        2: begin
                                            dist[k] = (cv0[0] - cv2[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv0[1] - cv2[1])*(cv0[1] - cv2[1])) + 
                                                        ((cv0[2] - cv2[2])*(cv0[2] - cv2[2]));
                                        end
                                        3: begin
                                            dist[k] = (cv0[0] - cv3[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv0[1] - cv3[1])*(cv0[1] - cv3[1])) + 
                                                        ((cv0[2] - cv3[2])*(cv0[2] - cv3[2]));
                                        end
                                        4: begin
                                            dist[k] = (cv0[0] - cv4[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv0[1] - cv4[1])*(cv0[1] - cv4[1])) + 
                                                        ((cv0[2] - cv4[2])*(cv0[2] - cv4[2]));
                                        end
                                        5: begin
                                            dist[k] = (cv0[0] - cv5[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv0[1] - cv5[1])*(cv0[1] - cv5[1])) + 
                                                        ((cv0[2] - cv5[2])*(cv0[2] - cv5[2]));
                                        end
                                        6: begin
                                            dist[k] = (cv0[0] - cv6[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv0[1] - cv6[1])*(cv0[1] - cv6[1])) + 
                                                        ((cv0[2] - cv6[2])*(cv0[2] - cv6[2]));
                                        end
                                        7: begin
                                            dist[k] = (cv0[0] - cv7[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv0[1] - cv7[1])*(cv0[1] - cv7[1])) + 
                                                        ((cv0[2] - cv7[2])*(cv0[2] - cv7[2]));
                                        end
                                    endcase
                                end
                                1: begin
                                    case (j)
                                        2: begin
                                            dist[k] = (cv1[0] - cv2[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv1[1] - cv2[1])*(cv1[1] - cv2[1])) + 
                                                        ((cv1[2] - cv2[2])*(cv1[2] - cv2[2]));
                                        end
                                        3: begin
                                            dist[k] = (cv1[0] - cv3[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv1[1] - cv3[1])*(cv1[1] - cv3[1])) + 
                                                        ((cv1[2] - cv3[2])*(cv1[2] - cv3[2]));
                                        end
                                        4: begin
                                            dist[k] = (cv1[0] - cv4[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv1[1] - cv4[1])*(cv1[1] - cv4[1])) + 
                                                        ((cv1[2] - cv4[2])*(cv1[2] - cv4[2]));
                                        end
                                        5: begin
                                            dist[k] = (cv1[0] - cv5[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv1[1] - cv5[1])*(cv1[1] - cv5[1])) + 
                                                        ((cv1[2] - cv5[2])*(cv1[2] - cv5[2]));
                                        end
                                        6: begin
                                            dist[k] = (cv1[0] - cv6[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv1[1] - cv6[1])*(cv1[1] - cv6[1])) + 
                                                        ((cv1[2] - cv6[2])*(cv1[2] - cv6[2]));
                                        end
                                        7: begin
                                            dist[k] = (cv1[0] - cv7[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv1[1] - cv7[1])*(cv1[1] - cv7[1])) + 
                                                        ((cv1[2] - cv7[2])*(cv1[2] - cv7[2]));
                                        end
                                    endcase
                                end
                                2: begin
                                    case (j)
                                        3: begin
                                            dist[k] = (cv2[0] - cv3[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv2[1] - cv3[1])*(cv2[1] - cv3[1])) + 
                                                        ((cv2[2] - cv3[2])*(cv2[2] - cv3[2]));
                                        end
                                        4: begin
                                            dist[k] = (cv2[0] - cv4[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv2[1] - cv4[1])*(cv2[1] - cv4[1])) + 
                                                        ((cv2[2] - cv4[2])*(cv2[2] - cv4[2]));
                                        end
                                        5: begin
                                            dist[k] = (cv2[0] - cv5[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv2[1] - cv5[1])*(cv2[1] - cv5[1])) + 
                                                        ((cv2[2] - cv5[2])*(cv2[2] - cv5[2]));
                                        end
                                        6: begin
                                            dist[k] = (cv2[0] - cv6[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv2[1] - cv6[1])*(cv2[1] - cv6[1])) + 
                                                        ((cv2[2] - cv6[2])*(cv2[2] - cv6[2]));
                                        end
                                        7: begin
                                            dist[k] = (cv2[0] - cv7[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv2[1] - cv7[1])*(cv2[1] - cv7[1])) + 
                                                        ((cv2[2] - cv7[2])*(cv2[2] - cv7[2]));
                                        end
                                    endcase
                                end
                                3: begin
                                    case (j)
                                        4: begin
                                            dist[k] = (cv3[0] - cv4[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv3[1] - cv4[1])*(cv3[1] - cv4[1])) + 
                                                        ((cv3[2] - cv4[2])*(cv3[2] - cv4[2]));
                                        end
                                        5: begin
                                            dist[k] = (cv3[0] - cv5[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv3[1] - cv5[1])*(cv3[1] - cv5[1])) + 
                                                        ((cv3[2] - cv5[2])*(cv3[2] - cv5[2]));
                                        end
                                        6: begin
                                            dist[k] = (cv3[0] - cv6[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv3[1] - cv6[1])*(cv3[1] - cv6[1])) + 
                                                        ((cv3[2] - cv6[2])*(cv3[2] - cv6[2]));
                                        end
                                        7: begin
                                            dist[k] = (cv3[0] - cv7[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv3[1] - cv7[1])*(cv3[1] - cv7[1])) + 
                                                        ((cv3[2] - cv7[2])*(cv3[2] - cv7[2]));
                                        end
                                    endcase
                                end
                                4: begin
                                    case (j)
                                        5: begin
                                            dist[k] = (cv4[0] - cv5[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv4[1] - cv5[1])*(cv4[1] - cv5[1])) + 
                                                        ((cv4[2] - cv5[2])*(cv4[2] - cv5[2]));
                                        end
                                        6: begin
                                            dist[k] = (cv4[0] - cv6[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv4[1] - cv6[1])*(cv4[1] - cv6[1])) + 
                                                        ((cv4[2] - cv6[2])*(cv4[2] - cv6[2]));
                                        end
                                        7: begin
                                            dist[k] = (cv4[0] - cv7[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv4[1] - cv7[1])*(cv4[1] - cv7[1])) + 
                                                        ((cv4[2] - cv7[2])*(cv4[2] - cv7[2]));
                                        end
                                    endcase
                                end
                                5: begin
                                    case (j)
                                        6: begin
                                            dist[k] = (cv5[0] - cv6[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv5[1] - cv6[1])*(cv5[1] - cv6[1])) + 
                                                        ((cv5[2] - cv6[2])*(cv5[2] - cv6[2]));
                                        end
                                        7: begin
                                            dist[k] = (cv5[0] - cv7[0]);
                                            dist_sq[k] = dist[k]*dist[k] + 
                                                        ((cv5[1] - cv7[1])*(cv5[1] - cv7[1])) + 
                                                        ((cv5[2] - cv7[2])*(cv5[2] - cv7[2]));
                                        end
                                    endcase
                                end
                                6: begin
                                    if (j == 7) begin
                                        dist[k] = (cv6[0] - cv7[0]);
                                        dist_sq[k] = dist[k]*dist[k] + 
                                                    ((cv6[1] - cv7[1])*(cv6[1] - cv7[1])) + 
                                                    ((cv6[2] - cv7[2])*(cv6[2] - cv7[2]));
                                    end
                                end
                            endcase
                            k = k + 1;
                        end
                    end

                    // Analyze distances for cube pattern
                    // Find minimum non-zero distance (edge squared)
                    min_dist = 64'd0;
                    for (i = 0; i < 28; i = i + 1) begin
                        if (dist_sq[i] > 64'd0 && (min_dist == 64'd0 || dist_sq[i] < min_dist)) begin
                            min_dist = dist_sq[i];
                        end
                    end

                    // Count distances that match expected ratios
                    edge_count = 4'd0;
                    face_diag_count = 4'd0;
                    space_diag_count = 4'd0;

                    if (min_dist > 64'd0) begin
                        edge_sq = min_dist;
                        face_diag_sq = edge_sq * 64'd2;
                        space_diag_sq = edge_sq * 64'd3;

                        for (i = 0; i < 28; i = i + 1) begin
                            if (dist_sq[i] == edge_sq) begin
                                edge_count = edge_count + 4'd1;
                            end else if (dist_sq[i] == face_diag_sq) begin
                                face_diag_count = face_diag_count + 4'd1;
                            end else if (dist_sq[i] == space_diag_sq) begin
                                space_diag_count = space_diag_count + 4'd1;
                            end
                        end
                    end

                    // Check if we found a valid cube
                    if (edge_count == 4'd12 && face_diag_count == 4'd12 && space_diag_count == 4'd4) begin
                        // Valid cube found - output results
                        out_v0_x <= cv0[0]; out_v0_y <= cv0[1]; out_v0_z <= cv0[2];
                        out_v1_x <= cv1[0]; out_v1_y <= cv1[1]; out_v1_z <= cv1[2];
                        out_v2_x <= cv2[0]; out_v2_y <= cv2[1]; out_v2_z <= cv2[2];
                        out_v3_x <= cv3[0]; out_v3_y <= cv3[1]; out_v3_z <= cv3[2];
                        out_v4_x <= cv4[0]; out_v4_y <= cv4[1]; out_v4_z <= cv4[2];
                        out_v5_x <= cv5[0]; out_v5_y <= cv5[1]; out_v5_z <= cv5[2];
                        out_v6_x <= cv6[0]; out_v6_y <= cv6[1]; out_v6_z <= cv6[2];
                        out_v7_x <= cv7[0]; out_v7_y <= cv7[1]; out_v7_z <= cv7[2];
                        valid <= 1'b1;
                        state <= OUTPUT;
                    end else begin
                        // Increment permutation counters
                        perm7 = perm7 + 3'd1;
                        if (perm7 == 3'd6) begin
                            perm7 <= 3'd0;
                            perm6 = perm6 + 3'd1;
                            if (perm6 == 3'd6) begin
                                perm6 <= 3'd0;
                                perm5 = perm5 + 3'd1;
                                if (perm5 == 3'd6) begin
                                    perm5 <= 3'd0;
                                    perm4 = perm4 + 3'd1;
                                    if (perm4 == 3'd6) begin
                                        perm4 <= 3'd0;
                                        perm3 = perm3 + 3'd1;
                                        if (perm3 == 3'd6) begin
                                            perm3 <= 3'd0;
                                            perm2 = perm2 + 3'd1;
                                            if (perm2 == 3'd6) begin
                                                perm2 <= 3'd0;
                                                perm1 = perm1 + 3'd1;
                                                if (perm1 == 3'd6) begin
                                                    perm1 <= 3'd0;
                                                    perm0 = perm0 + 3'd1;
                                                    if (perm0 == 3'd6) begin
                                                        // All permutations exhausted
                                                        valid <= 1'b0;
                                                        state <= OUTPUT;
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        // Check cycle limit
                        if (cycle_count >= MAX_CYCLES) begin
                            valid <= 1'b0;
                            state <= OUTPUT;
                        end
                    end
                end

                OUTPUT: begin
                    done <= 1'b1;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule