module escape_calculator(
  input [1:0] n,
  input [1:0] e,
  input [3:0][3:0][6:0] roads,
  input [3:0] exits,
  input [1:0] b_start,
  input [1:0] p_start,
  output [31:0] min_speed
);

  localparam INF = 32'hFFFFFFFF;
  wire [31:0] INF32 = INF;

  // Floyd-Warshall distance matrices (5 stages)
  wire [31:0] dist_stage0 [3:0][3:0];
  wire [31:0] dist_stage1 [3:0][3:0];
  wire [31:0] dist_stage2 [3:0][3:0];
  wire [31:0] dist_stage3 [3:0][3:0];
  wire [31:0] dist_stage4 [3:0][3:0];

  // Stage 0: Initialization
  generate
    for (genvar i = 0; i < 4; i++) begin : stage0_row
      for (genvar j = 0; j < 4; j++) begin : stage0_col
        assign dist_stage0[i][j] = (i == j) ? 32'b0 :
          ((i < n) && (j < n) && (roads[i][j] != 7'b0)) ? {25'b0, roads[i][j]} : INF;
      end
    end
  endgenerate

  // Stage 1: k=0
  generate
    for (genvar i = 0; i < 4; i++) begin : stage1_row
      for (genvar j = 0; j < 4; j++) begin : stage1_col
        wire [31:0] via_k = dist_stage0[i][0] + dist_stage0[0][j];
        assign dist_stage1[i][j] = ((i < n) && (j < n) && (0 < n) &&
          (via_k < dist_stage0[i][j])) ? via_k : dist_stage0[i][j];
      end
    end
  endgenerate

  // Stage 2: k=1
  generate
    for (genvar i = 0; i < 4; i++) begin : stage2_row
      for (genvar j = 0; j < 4; j++) begin : stage2_col
        wire [31:0] via_k = dist_stage1[i][1] + dist_stage1[1][j];
        assign dist_stage2[i][j] = ((i < n) && (j < n) && (1 < n) &&
          (via_k < dist_stage1[i][j])) ? via_k : dist_stage1[i][j];
      end
    end
  endgenerate

  // Stage 3: k=2
  generate
    for (genvar i = 0; i < 4; i++) begin : stage3_row
      for (genvar j = 0; j < 4; j++) begin : stage3_col
        wire [31:0] via_k = dist_stage2[i][2] + dist_stage2[2][j];
        assign dist_stage3[i][j] = ((i < n) && (j < n) && (2 < n) &&
          (via_k < dist_stage2[i][j])) ? via_k : dist_stage2[i][j];
      end
    end
  endgenerate

  // Stage 4: k=3
  generate
    for (genvar i = 0; i < 4; i++) begin : stage4_row
      for (genvar j = 0; j < 4; j++) begin : stage4_col
        wire [31:0] via_k = dist_stage3[i][3] + dist_stage3[3][j];
        assign dist_stage4[i][j] = ((i < n) && (j < n) && (3 < n) &&
          (via_k < dist_stage3[i][j])) ? via_k : dist_stage3[i][j];
      end
    end
  endgenerate

  // Extract distances for b_start and p_start
  wire [31:0] brothers_dist [3:0];
  wire [31:0] police_dist [3:0];
  generate
    for (genvar i = 0; i < 4; i++) begin : extract_dist
      assign brothers_dist[i] = dist_stage4[b_start][i];
      assign police_dist[i] = dist_stage4[p_start][i];
    end
  endgenerate

  // Process each exit
  wire [31:0] exit_speed [3:0];
  generate
    for (genvar i = 0; i < 4; i++) begin : compute_speed
      wire valid_exit = (i < n) && exits[i];
      wire both_nonzero = (brothers_dist[i] != 0) && (police_dist[i] != 0);
      wire both_finite = (brothers_dist[i] != INF) && (police_dist[i] != INF);
      wire is_valid = valid_exit && both_nonzero && both_finite;

      wire [31:0] brother_x160 = brothers_dist[i] * 32'd160;
      wire [31:0] numerator = {brother_x160[15:0], 16'b0}; // x65536
      wire [31:0] speed_raw = numerator / police_dist[i];

      assign exit_speed[i] = is_valid ? speed_raw : INF;
    end
  endgenerate

  // Find minimum valid speed
  wire [31:0] min01 = (exit_speed[0] <= exit_speed[1]) ? exit_speed[0] : exit_speed[1];
  wire [31:0] min23 = (exit_speed[2] <= exit_speed[3]) ? exit_speed[2] : exit_speed[3];
  wire [31:0] min_speed_int = (min01 <= min23) ? min01 : min23;
  assign min_speed = (min_speed_int == INF) ? 32'hFFFFFFFF : min_speed_int;

endmodule