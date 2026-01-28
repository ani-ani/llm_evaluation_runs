module cube_checker (
  input signed [23:0] in0_0, in0_1, in0_2,
  input signed [23:0] in1_0, in1_1, in1_2,
  input signed [23:0] in2_0, in2_1, in2_2,
  input signed [23:0] in3_0, in3_1, in3_2,
  input signed [23:0] in4_0, in4_1, in4_2,
  input signed [23:0] in5_0, in5_1, in5_2,
  input signed [23:0] in6_0, in6_1, in6_2,
  input signed [23:0] in7_0, in7_1, in7_2,
  output reg is_cube,
  output reg [23:0] out0_0, out0_1, out0_2,
  output reg [23:0] out1_0, out1_1, out1_2,
  output reg [23:0] out2_0, out2_1, out2_2,
  output reg [23:0] out3_0, out3_1, out3_2,
  output reg [23:0] out4_0, out4_1, out4_2,
  output reg [23:0] out5_0, out5_1, out5_2,
  output reg [23:0] out6_0, out6_1, out6_2,
  output reg [23:0] out7_0, out7_1, out7_2
);

  reg [23:0] points [0:7][0:2];
  integer i;

  always @(*) begin
    points[0][0] = in0_0;
    points[0][1] = in0_1;
    points[0][2] = in0_2;
    points[1][0] = in1_0;
    points[1][1] = in1_1;
    points[1][2] = in1_2;
    points[2][0] = in2_0;
    points[2][1] = in2_1;
    points[2][2] = in2_2;
    points[3][0] = in3_0;
    points[3][1] = in3_1;
    points[3][2] = in3_2;
    points[4][0] = in4_0;
    points[4][1] = in4_1;
    points[4][2] = in4_2;
    points[5][0] = in5_0;
    points[5][1] = in5_1;
    points[5][2] = in5_2;
    points[6][0] = in6_0;
    points[6][1] = in6_1;
    points[6][2] = in6_2;
    points[7][0] = in7_0;
    points[7][1] = in7_1;
    points[7][2] = in7_2;
  end

  reg signed [63:0] dist2 [0:27];
  reg signed [63:0] dx, dy, dz;
  integer j, k;

  always @(*) begin
    k = 0;
    for (i = 0; i < 8; i = i + 1) begin
      for (j = i + 1; j < 8; j = j + 1) begin
        dx = points[i][0] - points[j][0];
        dy = points[i][1] - points[j][1];
        dz = points[i][2] - points[j][2];
        dist2[k] = dx * dx + dy * dy + dz * dz;
        k = k + 1;
      end
    end
  end

  reg signed [63:0] min_dist2;
  reg found_min;

  always @(*) begin
    min_dist2 = 64'h7FFFFFFFFFFFFFFF;
    found_min = 1'b0;
    for (k = 0; k < 28; k = k + 1) begin
      if (dist2[k] > 0 && dist2[k] < min_dist2) begin
        min_dist2 = dist2[k];
        found_min = 1'b1;
      end
    end
  end

  reg [2:0] edge_count [0:7];
  reg [2:0] face_count [0:7];
  reg [2:0] space_count [0:7];
  reg [2:0] edge_errors, face_errors, space_errors;
  reg valid_distances;
  integer p_idx;

  always @(*) begin
    for (i = 0; i < 8; i = i + 1) begin
      edge_count[i] = 3'd0;
      face_count[i] = 3'd0;
      space_count[i] = 3'd0;
    end
    edge_errors = 3'd0;
    face_errors = 3'd0;
    space_errors = 3'd0;
    valid_distances = 1'b1;
    p_idx = 0;

    for (i = 0; i < 8; i = i + 1) begin
      for (j = i + 1; j < 8; j = j + 1) begin
        if (dist2[p_idx] == 0) begin
          valid_distances = 1'b0;
        end else if (dist2[p_idx] == min_dist2) begin
          edge_count[i] = edge_count[i] + 3'd1;
          edge_count[j] = edge_count[j] + 3'd1;
        end else if (dist2[p_idx] == 2 * min_dist2) begin
          face_count[i] = face_count[i] + 3'd1;
          face_count[j] = face_count[j] + 3'd1;
        end else if (dist2[p_idx] == 3 * min_dist2) begin
          space_count[i] = space_count[i] + 3'd1;
          space_count[j] = space_count[j] + 3'd1;
        end else begin
          valid_distances = 1'b0;
        end
        p_idx = p_idx + 1;
      end
    end

    for (i = 0; i < 8; i = i + 1) begin
      if (edge_count[i] != 3'd3) begin
        edge_errors = edge_errors + 3'd1;
      end
      if (face_count[i] != 3'd3) begin
        face_errors = face_errors + 3'd1;
      end
      if (space_count[i] != 3'd1) begin
        space_errors = space_errors + 3'd1;
      end
    end
  end

  always @(*) begin
    out0_0 = in0_0;
    out0_1 = in0_1;
    out0_2 = in0_2;
    out1_0 = in1_0;
    out1_1 = in1_1;
    out1_2 = in1_2;
    out2_0 = in2_0;
    out2_1 = in2_1;
    out2_2 = in2_2;
    out3_0 = in3_0;
    out3_1 = in3_1;
    out3_2 = in3_2;
    out4_0 = in4_0;
    out4_1 = in4_1;
    out4_2 = in4_2;
    out5_0 = in5_0;
    out5_1 = in5_1;
    out5_2 = in5_2;
    out6_0 = in6_0;
    out6_1 = in6_1;
    out6_2 = in6_2;
    out7_0 = in7_0;
    out7_1 = in7_1;
    out7_2 = in7_2;

    is_cube = valid_distances && found_min && (edge_errors == 3'd0) && (face_errors == 3'd0) && (space_errors == 3'd0);
  end

endmodule