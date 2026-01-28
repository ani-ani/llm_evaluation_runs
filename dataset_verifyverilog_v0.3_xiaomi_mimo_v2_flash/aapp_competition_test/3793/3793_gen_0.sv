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
  // Form points from inputs
  wire signed [23:0] points0_0, points0_1, points0_2;
  wire signed [23:0] points1_0, points1_1, points1_2;
  wire signed [23:0] points2_0, points2_1, points2_2;
  wire signed [23:0] points3_0, points3_1, points3_2;
  wire signed [23:0] points4_0, points4_1, points4_2;
  wire signed [23:0] points5_0, points5_1, points5_2;
  wire signed [23:0] points6_0, points6_1, points6_2;
  wire signed [23:0] points7_0, points7_1, points7_2;

  assign points0_0 = in0_0; assign points0_1 = in0_1; assign points0_2 = in0_2;
  assign points1_0 = in1_0; assign points1_1 = in1_1; assign points1_2 = in1_2;
  assign points2_0 = in2_0; assign points2_1 = in2_1; assign points2_2 = in2_2;
  assign points3_0 = in3_0; assign points3_1 = in3_1; assign points3_2 = in3_2;
  assign points4_0 = in4_0; assign points4_1 = in4_1; assign points4_2 = in4_2;
  assign points5_0 = in5_0; assign points5_1 = in5_1; assign points5_2 = in5_2;
  assign points6_0 = in6_0; assign points6_1 = in6_1; assign points6_2 = in6_2;
  assign points7_0 = in7_0; assign points7_1 = in7_1; assign points7_2 = in7_2;

  // Compute all 28 squared distances
  wire signed [63:0] d00, d01, d02, d03, d04, d05, d06, d07;
  wire signed [63:0] d12, d13, d14, d15, d16, d17;
  wire signed [63:0] d23, d24, d25, d26, d27;
  wire signed [63:0] d34, d35, d36, d37;
  wire signed [63:0] d45, d46, d47;
  wire signed [63:0] d56, d57;
  wire signed [63:0] d67;
  wire signed [63:0] dx, dy, dz;

  // Pair 0-1
  assign dx = points0_0 - points1_0;
  assign dy = points0_1 - points1_1;
  assign dz = points0_2 - points1_2;
  assign d00 = dx*dx + dy*dy + dz*dz;
  // Pair 0-2
  assign dx = points0_0 - points2_0;
  assign dy = points0_1 - points2_1;
  assign dz = points0_2 - points2_2;
  assign d01 = dx*dx + dy*dy + dz*dz;
  // Pair 0-3
  assign dx = points0_0 - points3_0;
  assign dy = points0_1 - points3_1;
  assign dz = points0_2 - points3_2;
  assign d02 = dx*dx + dy*dy + dz*dz;
  // Pair 0-4
  assign dx = points0_0 - points4_0;
  assign dy = points0_1 - points4_1;
  assign dz = points0_2 - points4_2;
  assign d03 = dx*dx + dy*dy + dz*dz;
  // Pair 0-5
  assign dx = points0_0 - points5_0;
  assign dy = points0_1 - points5_1;
  assign dz = points0_2 - points5_2;
  assign d04 = dx*dx + dy*dy + dz*dz;
  // Pair 0-6
  assign dx = points0_0 - points6_0;
  assign dy = points0_1 - points6_1;
  assign dz = points0_2 - points6_2;
  assign d05 = dx*dx + dy*dy + dz*dz;
  // Pair 0-7
  assign dx = points0_0 - points7_0;
  assign dy = points0_1 - points7_1;
  assign dz = points0_2 - points7_2;
  assign d06 = dx*dx + dy*dy + dz*dz;
  // Pair 1-2
  assign dx = points1_0 - points2_0;
  assign dy = points1_1 - points2_1;
  assign dz = points1_2 - points2_2;
  assign d07 = dx*dx + dy*dy + dz*dz;
  // Pair 1-3
  assign dx = points1_0 - points3_0;
  assign dy = points1_1 - points3_1;
  assign dz = points1_2 - points3_2;
  assign d12 = dx*dx + dy*dy + dz*dz;
  // Pair 1-4
  assign dx = points1_0 - points4_0;
  assign dy = points1_1 - points4_1;
  assign dz = points1_2 - points4_2;
  assign d13 = dx*dx + dy*dy + dz*dz;
  // Pair 1-5
  assign dx = points1_0 - points5_0;
  assign dy = points1_1 - points5_1;
  assign dz = points1_2 - points5_2;
  assign d14 = dx*dx + dy*dy + dz*dz;
  // Pair 1-6
  assign dx = points1_0 - points6_0;
  assign dy = points1_1 - points6_1;
  assign dz = points1_2 - points6_2;
  assign d15 = dx*dx + dy*dy + dz*dz;
  // Pair 1-7
  assign dx = points1_0 - points7_0;
  assign dy = points1_1 - points7_1;
  assign dz = points1_2 - points7_2;
  assign d16 = dx*dx + dy*dy + dz*dz;
  // Pair 2-3
  assign dx = points2_0 - points3_0;
  assign dy = points2_1 - points3_1;
  assign dz = points2_2 - points3_2;
  assign d17 = dx*dx + dy*dy + dz*dz;
  // Pair 2-4
  assign dx = points2_0 - points4_0;
  assign dy = points2_1 - points4_1;
  assign dz = points2_2 - points4_2;
  assign d23 = dx*dx + dy*dy + dz*dz;
  // Pair 2-5
  assign dx = points2_0 - points5_0;
  assign dy = points2_1 - points5_1;
  assign dz = points2_2 - points5_2;
  assign d24 = dx*dx + dy*dy + dz*dz;
  // Pair 2-6
  assign dx = points2_0 - points6_0;
  assign dy = points2_1 - points6_1;
  assign dz = points2_2 - points6_2;
  assign d25 = dx*dx + dy*dy + dz*dz;
  // Pair 2-7
  assign dx = points2_0 - points7_0;
  assign dy = points2_1 - points7_1;
  assign dz = points2_2 - points7_2;
  assign d26 = dx*dx + dy*dy + dz*dz;
  // Pair 3-4
  assign dx = points3_0 - points4_0;
  assign dy = points3_1 - points4_1;
  assign dz = points3_2 - points4_2;
  assign d27 = dx*dx + dy*dy + dz*dz;
  // Pair 3-5
  assign dx = points3_0 - points5_0;
  assign dy = points3_1 - points5_1;
  assign dz = points3_2 - points5_2;
  assign d34 = dx*dx + dy*dy + dz*dz;
  // Pair 3-6
  assign dx = points3_0 - points6_0;
  assign dy = points3_1 - points6_1;
  assign dz = points3_2 - points6_2;
  assign d35 = dx*dx + dy*dy + dz*dz;
  // Pair 3-7
  assign dx = points3_0 - points7_0;
  assign dy = points3_1 - points7_1;
  assign dz = points3_2 - points7_2;
  assign d36 = dx*dx + dy*dy + dz*dz;
  // Pair 4-5
  assign dx = points4_0 - points5_0;
  assign dy = points4_1 - points5_1;
  assign dz = points4_2 - points5_2;
  assign d37 = dx*dx + dy*dy + dz*dz;
  // Pair 4-6
  assign dx = points4_0 - points6_0;
  assign dy = points4_1 - points6_1;
  assign dz = points4_2 - points6_2;
  assign d45 = dx*dx + dy*dy + dz*dz;
  // Pair 4-7
  assign dx = points4_0 - points7_0;
  assign dy = points4_1 - points7_1;
  assign dz = points4_2 - points7_2;
  assign d46 = dx*dx + dy*dy + dz*dz;
  // Pair 5-6
  assign dx = points5_0 - points6_0;
  assign dy = points5_1 - points6_1;
  assign dz = points5_2 - points6_2;
  assign d47 = dx*dx + dy*dy + dz*dz;
  // Pair 5-7
  assign dx = points5_0 - points7_0;
  assign dy = points5_1 - points7_1;
  assign dz = points5_2 - points7_2;
  assign d56 = dx*dx + dy*dy + dz*dz;
  // Pair 6-7
  assign dx = points6_0 - points7_0;
  assign dy = points6_1 - points7_1;
  assign dz = points6_2 - points7_2;
  assign d57 = dx*dx + dy*dy + dz*dz;
  // Extra pairs for counting
  assign d67 = dx*dx + dy*dy + dz*dz;

  // Find minimal non-zero distance squared
  reg signed [63:0] min_dist2;
  reg found_min;
  always @(*) begin
    min_dist2 = 64'h7FFFFFFFFFFFFFFF;
    found_min = 0;
    if (d00 > 0 && d00 < min_dist2) begin min_dist2 = d00; found_min = 1; end
    if (d01 > 0 && d01 < min_dist2) begin min_dist2 = d01; found_min = 1; end
    if (d02 > 0 && d02 < min_dist2) begin min_dist2 = d02; found_min = 1; end
    if (d03 > 0 && d03 < min_dist2) begin min_dist2 = d03; found_min = 1; end
    if (d04 > 0 && d04 < min_dist2) begin min_dist2 = d04; found_min = 1; end
    if (d05 > 0 && d05 < min_dist2) begin min_dist2 = d05; found_min = 1; end
    if (d06 > 0 && d06 < min_dist2) begin min_dist2 = d06; found_min = 1; end
    if (d07 > 0 && d07 < min_dist2) begin min_dist2 = d07; found_min = 1; end
    if (d12 > 0 && d12 < min_dist2) begin min_dist2 = d12; found_min = 1; end
    if (d13 > 0 && d13 < min_dist2) begin min_dist2 = d13; found_min = 1; end
    if (d14 > 0 && d14 < min_dist2) begin min_dist2 = d14; found_min = 1; end
    if (d15 > 0 && d15 < min_dist2) begin min_dist2 = d15; found_min = 1; end
    if (d16 > 0 && d16 < min_dist2) begin min_dist2 = d16; found_min = 1; end
    if (d17 > 0 && d17 < min_dist2) begin min_dist2 = d17; found_min = 1; end
    if (d23 > 0 && d23 < min_dist2) begin min_dist2 = d23; found_min = 1; end
    if (d24 > 0 && d24 < min_dist2) begin min_dist2 = d24; found_min = 1; end
    if (d25 > 0 && d25 < min_dist2) begin min_dist2 = d25; found_min = 1; end
    if (d26 > 0 && d26 < min_dist2) begin min_dist2 = d26; found_min = 1; end
    if (d27 > 0 && d27 < min_dist2) begin min_dist2 = d27; found_min = 1; end
    if (d34 > 0 && d34 < min_dist2) begin min_dist2 = d34; found_min = 1; end
    if (d35 > 0 && d35 < min_dist2) begin min_dist2 = d35; found_min = 1; end
    if (d36 > 0 && d36 < min_dist2) begin min_dist2 = d36; found_min = 1; end
    if (d37 > 0 && d37 < min_dist2) begin min_dist2 = d37; found_min = 1; end
    if (d45 > 0 && d45 < min_dist2) begin min_dist2 = d45; found_min = 1; end
    if (d46 > 0 && d46 < min_dist2) begin min_dist2 = d46; found_min = 1; end
    if (d47 > 0 && d47 < min_dist2) begin min_dist2 = d47; found_min = 1; end
    if (d56 > 0 && d56 < min_dist2) begin min_dist2 = d56; found_min = 1; end
    if (d57 > 0 && d57 < min_dist2) begin min_dist2 = d57; found_min = 1; end
  end

  // Verify distance ratios and counts
  reg [2:0] edge0, edge1, edge2, edge3, edge4, edge5, edge6, edge7;
  reg [2:0] face0, face1, face2, face3, face4, face5, face6, face7;
  reg [2:0] space0, space1, space2, space3, space4, space5, space6, space7;
  reg edge_errors, face_errors, space_errors;
  reg valid_distances;

  always @(*) begin
    // Initialize counters
    edge0 = 0; edge1 = 0; edge2 = 0; edge3 = 0;
    edge4 = 0; edge5 = 0; edge6 = 0; edge7 = 0;
    face0 = 0; face1 = 0; face2 = 0; face3 = 0;
    face4 = 0; face5 = 0; face6 = 0; face7 = 0;
    space0 = 0; space1 = 0; space2 = 0; space3 = 0;
    space4 = 0; space5 = 0; space6 = 0; space7 = 0;
    edge_errors = 0;
    face_errors = 0;
    space_errors = 0;
    valid_distances = 1;

    // Check all pairs - edges (min_dist2), faces (2*min_dist2), space (3*min_dist2)
    // 0-1
    if (d00 == 0) valid_distances = 0;
    else if (d00 == min_dist2) begin edge0 = edge0 + 1; edge1 = edge1 + 1; end
    else if (d00 == (min_dist2 << 1)) begin face0 = face0 + 1; face1 = face1 + 1; end
    else if (d00 == (min_dist2 + (min_dist2 << 1))) begin space0 = space0 + 1; space1 = space1 + 1; end
    else valid_distances = 0;
    // 0-2
    if (d01 == 0) valid_distances = 0;
    else if (d01 == min_dist2) begin edge0 = edge0 + 1; edge2 = edge2 + 1; end
    else if (d01 == (min_dist2 << 1)) begin face0 = face0 + 1; face2 = face2 + 1; end
    else if (d01 == (min_dist2 + (min_dist2 << 1))) begin space0 = space0 + 1; space2 = space2 + 1; end
    else valid_distances = 0;
    // 0-3
    if (d02 == 0) valid_distances = 0;
    else if (d02 == min_dist2) begin edge0 = edge0 + 1; edge3 = edge3 + 1; end
    else if (d02 == (min_dist2 << 1)) begin face0 = face0 + 1; face3 = face3 + 1; end
    else if (d02 == (min_dist2 + (min_dist2 << 1))) begin space0 = space0 + 1; space3 = space3 + 1; end
    else valid_distances = 0;
    // 0-4
    if (d03 == 0) valid_distances = 0;
    else if (d03 == min_dist2) begin edge0 = edge0 + 1; edge4 = edge4 + 1; end
    else if (d03 == (min_dist2 << 1)) begin face0 = face0 + 1; face4 = face4 + 1; end
    else if (d03 == (min_dist2 + (min_dist2 << 1))) begin space0 = space0 + 1; space4 = space4 + 1; end
    else valid_distances = 0;
    // 0-5
    if (d04 == 0) valid_distances = 0;
    else if (d04 == min_dist2) begin edge0 = edge0 + 1; edge5 = edge5 + 1; end
    else if (d04 == (min_dist2 << 1)) begin face0 = face0 + 1; face5 = face5 + 1; end
    else if (d04 == (min_dist2 + (min_dist2 << 1))) begin space0 = space0 + 1; space5 = space5 + 1; end
    else valid_distances = 0;
    // 0-6
    if (d05 == 0) valid_distances = 0;
    else if (d05 == min_dist2) begin edge0 = edge0 + 1; edge6 = edge6 + 1; end
    else if (d05 == (min_dist2 << 1)) begin face0 = face0 + 1; face6 = face6 + 1; end
    else if (d05 == (min_dist2 + (min_dist2 << 1))) begin space0 = space0 + 1; space6 = space6 + 1; end
    else valid_distances = 0;
    // 0-7
    if (d06 == 0) valid_distances = 0;
    else if (d06 == min_dist2) begin edge0 = edge0 + 1; edge7 = edge7 + 1; end
    else if (d06 == (min_dist2 << 1)) begin face0 = face0 + 1; face7 = face7 + 1; end
    else if (d06 == (min_dist2 + (min_dist2 << 1))) begin space0 = space0 + 1; space7 = space7 + 1; end
    else valid_distances = 0;
    // 1-2
    if (d07 == 0) valid_distances = 0;
    else if (d07 == min_dist2) begin edge1 = edge1 + 1; edge2 = edge2 + 1; end
    else if (d07 == (min_dist2 << 1)) begin face1 = face1 + 1; face2 = face2 + 1; end
    else if (d07 == (min_dist2 + (min_dist2 << 1))) begin space1 = space1 + 1; space2 = space2 + 1; end
    else valid_distances = 0;
    // 1-3
    if (d12 == 0) valid_distances = 0;
    else if (d12 == min_dist2) begin edge1 = edge1 + 1; edge3 = edge3 + 1; end
    else if (d12 == (min_dist2 << 1)) begin face1 = face1 + 1; face3 = face3 + 1; end
    else if (d12 == (min_dist2 + (min_dist2 << 1))) begin space1 = space1 + 1; space3 = space3 + 1; end
    else valid_distances = 0;
    // 1-4
    if (d13 == 0) valid_distances = 0;
    else if (d13 == min_dist2) begin edge1 = edge1 + 1; edge4 = edge4 + 1; end
    else if (d13 == (min_dist2 << 1)) begin face1 = face1 + 1; face4 = face4 + 1; end
    else if (d13 == (min_dist2 + (min_dist2 << 1))) begin space1 = space1 + 1; space4 = space4 + 1; end
    else valid_distances = 0;
    // 1-5
    if (d14 == 0) valid_distances = 0;
    else if (d14 == min_dist2) begin edge1 = edge1 + 1; edge5 = edge5 + 1; end
    else if (d14 == (min_dist2 << 1)) begin face1 = face1 + 1; face5 = face5 + 1; end
    else if (d14 == (min_dist2 + (min_dist2 << 1))) begin space1 = space1 + 1; space5 = space5 + 1; end
    else valid_distances = 0;
    // 1-6
    if (d15 == 0) valid_distances = 0;
    else if (d15 == min_dist2) begin edge1 = edge1 + 1; edge6 = edge6 + 1; end
    else if (d15 == (min_dist2 << 1)) begin face1 = face1 + 1; face6 = face6 + 1; end
    else if (d15 == (min_dist2 + (min_dist2 << 1))) begin space1 = space1 + 1; space6 = space6 + 1; end
    else valid_distances = 0;
    // 1-7
    if (d16 == 0) valid_distances = 0;
    else if (d16 == min_dist2) begin edge1 = edge1 + 1; edge7 = edge7 + 1; end
    else if (d16 == (min_dist2 << 1)) begin face1 = face1 + 1; face7 = face7 + 1; end
    else if (d16 == (min_dist2 + (min_dist2 << 1))) begin space1 = space1 + 1; space7 = space7 + 1; end
    else valid_distances = 0;
    // 2-3
    if (d17 == 0) valid_distances = 0;
    else if (d17 == min_dist2) begin edge2 = edge2 + 1; edge3 = edge3 + 1; end
    else if (d17 == (min_dist2 << 1)) begin face2 = face2 + 1; face3 = face3 + 1; end
    else if (d17 == (min_dist2 + (min_dist2 << 1))) begin space2 = space2 + 1; space3 = space3 + 1; end
    else valid_distances = 0;
    // 2-4
    if (d23 == 0) valid_distances = 0;
    else if (d23 == min_dist2) begin edge2 = edge2 + 1; edge4 = edge4 + 1; end
    else if (d23 == (min_dist2 << 1)) begin face2 = face2 + 1; face4 = face4 + 1; end
    else if (d23 == (min_dist2 + (min_dist2 << 1))) begin space2 = space2 + 1; space4 = space4 + 1; end
    else valid_distances = 0;
    // 2-5
    if (d24 == 0) valid_distances = 0;
    else if (d24 == min_dist2) begin edge2 = edge2 + 1; edge5 = edge5 + 1; end
    else if (d24 == (min_dist2 << 1)) begin face2 = face2 + 1; face5 = face5 + 1; end
    else if (d24 == (min_dist2 + (min_dist2 << 1))) begin space2 = space2 + 1; space5 = space5 + 1; end
    else valid_distances = 0;
    // 2-6
    if (d25 == 0) valid_distances = 0;
    else if (d25 == min_dist2) begin edge2 = edge2 + 1; edge6 = edge6 + 1; end
    else if (d25 == (min_dist2 << 1)) begin face2 = face2 + 1; face6 = face6 + 1; end
    else if (d25 == (min_dist2 + (min_dist2 << 1))) begin space2 = space2 + 1; space6 = space6 + 1; end
    else valid_distances = 0;
    // 2-7
    if (d26 == 0) valid_distances = 0;
    else if (d26 == min_dist2) begin edge2 = edge2 + 1; edge7 = edge7 + 1; end
    else if (d26 == (min_dist2 << 1)) begin face2 = face2 + 1; face7 = face7 + 1; end
    else if (d26 == (min_dist2 + (min_dist2 << 1))) begin space2 = space2 + 1; space7 = space7 + 1; end
    else valid_distances = 0;
    // 3-4
    if (d27 == 0) valid_distances = 0;
    else if (d27 == min_dist2) begin edge3 = edge3 + 1; edge4 = edge4 + 1; end
    else if (d27 == (min_dist2 << 1)) begin face3 = face3 + 1; face4 = face4 + 1; end
    else if (d27 == (min_dist2 + (min_dist2 << 1))) begin space3 = space3 + 1; space4 = space4 + 1; end
    else valid_distances = 0;
    // 3-5
    if (d34 == 0) valid_distances = 0;
    else if (d34 == min_dist2) begin edge3 = edge3 + 1; edge5 = edge5 + 1; end
    else if (d34 == (min_dist2 << 1)) begin face3 = face3 + 1; face5 = face5 + 1; end
    else if (d34 == (min_dist2 + (min_dist2 << 1))) begin space3 = space3 + 1; space5 = space5 + 1; end
    else valid_distances = 0;
    // 3-6
    if (d35 == 0) valid_distances = 0;
    else if (d35 == min_dist2) begin edge3 = edge3 + 1; edge6 = edge6 + 1; end
    else if (d35 == (min_dist2 << 1)) begin face3 = face3 + 1; face6 = face6 + 1; end
    else if (d35 == (min_dist2 + (min_dist2 << 1))) begin space3 = space3 + 1; space6 = space6 + 1; end
    else valid_distances = 0;
    // 3-7
    if (d36 == 0) valid_distances = 0;
    else if (d36 == min_dist2) begin edge3 = edge3 + 1; edge7 = edge7 + 1; end
    else if (d36 == (min_dist2 << 1)) begin face3 = face3 + 1; face7 = face7 + 1; end
    else if (d36 == (min_dist2 + (min_dist2 << 1))) begin space3 = space3 + 1; space7 = space7 + 1; end
    else valid_distances = 0;
    // 4-5
    if (d37 == 0) valid_distances = 0;
    else if (d37 == min_dist2) begin edge4 = edge4 + 1; edge5 = edge5 + 1; end
    else if (d37 == (min_dist2 << 1)) begin face4 = face4 + 1; face5 = face5 + 1; end
    else if (d37 == (min_dist2 + (min_dist2 << 1))) begin space4 = space4 + 1; space5 = space5 + 1; end
    else valid_distances = 0;
    // 4-6
    if (d45 == 0) valid_distances = 0;
    else if (d45 == min_dist2) begin edge4 = edge4 + 1; edge6 = edge6 + 1; end
    else if (d45 == (min_dist2 << 1)) begin face4 = face4 + 1; face6 = face6 + 1; end
    else if (d45 == (min_dist2 + (min_dist2 << 1))) begin space4 = space4 + 1; space6 = space6 + 1; end
    else valid_distances = 0;
    // 4-7
    if (d46 == 0) valid_distances = 0;
    else if (d46 == min_dist2) begin edge4 = edge4 + 1; edge7 = edge7 + 1; end
    else if (d46 == (min_dist2 << 1)) begin face4 = face4 + 1; face7 = face7 + 1; end
    else if (d46 == (min_dist2 + (min_dist2 << 1))) begin space4 = space4 + 1; space7 = space7 + 1; end
    else valid_distances = 0;
    // 5-6
    if (d47 == 0) valid_distances = 0;
    else if (d47 == min_dist2) begin edge5 = edge5 + 1; edge6 = edge6 + 1; end
    else if (d47 == (min_dist2 << 1)) begin face5 = face5 + 1; face6 = face6 + 1; end
    else if (d47 == (min_dist2 + (min_dist2 << 1))) begin space5 = space5 + 1; space6 = space6 + 1; end
    else valid_distances = 0;
    // 5-7
    if (d56 == 0) valid_distances = 0;
    else if (d56 == min_dist2) begin edge5 = edge5 + 1; edge7 = edge7 + 1; end
    else if (d56 == (min_dist2 << 1)) begin face5 = face5 + 1; face7 = face7 + 1; end
    else if (d56 == (min_dist2 + (min_dist2 << 1))) begin space5 = space5 + 1; space7 = space7 + 1; end
    else valid_distances = 0;
    // 6-7
    if (d57 == 0) valid_distances = 0;
    else if (d57 == min_dist2) begin edge6 = edge6 + 1; edge7 = edge7 + 1; end
    else if (d57 == (min_dist2 << 1)) begin face6 = face6 + 1; face7 = face7 + 1; end
    else if (d57 == (min_dist2 + (min_dist2 << 1))) begin space6 = space6 + 1; space7 = space7 + 1; end
    else valid_distances = 0;

    // Verify counts per vertex (3 edges, 3 faces, 1 space)
    if (edge0 != 3) edge_errors = 1;
    if (edge1 != 3) edge_errors = 1;
    if (edge2 != 3) edge_errors = 1;
    if (edge3 != 3) edge_errors = 1;
    if (edge4 != 3) edge_errors = 1;
    if (edge5 != 3) edge_errors = 1;
    if (edge6 != 3) edge_errors = 1;
    if (edge7 != 3) edge_errors = 1;
    if (face0 != 3) face_errors = 1;
    if (face1 != 3) face_errors = 1;
    if (face2 != 3) face_errors = 1;
    if (face3 != 3) face_errors = 1;
    if (face4 != 3) face_errors = 1;
    if (face5 != 3) face_errors = 1;
    if (face6 != 3) face_errors = 1;
    if (face7 != 3) face_errors = 1;
    if (space0 != 1) space_errors = 1;
    if (space1 != 1) space_errors = 1;
    if (space2 != 1) space_errors = 1;
    if (space3 != 1) space_errors = 1;
    if (space4 != 1) space_errors = 1;
    if (space5 != 1) space_errors = 1;
    if (space6 != 1) space_errors = 1;
    if (space7 != 1) space_errors = 1;
  end

  // Output assignments
  always @(*) begin
    // Pass through inputs
    out0_0 = in0_0; out0_1 = in0_1; out0_2 = in0_2;
    out1_0 = in1_0; out1_1 = in1_1; out1_2 = in1_2;
    out2_0 = in2_0; out2_1 = in2_1; out2_2 = in2_2;
    out3_0 = in3_0; out3_1 = in3_1; out3_2 = in3_2;
    out4_0 = in4_0; out4_1 = in4_1; out4_2 = in4_2;
    out5_0 = in5_0; out5_1 = in5_1; out5_2 = in5_2;
    out6_0 = in6_0; out6_1 = in6_1; out6_2 = in6_2;
    out7_0 = in7_0; out7_1 = in7_1; out7_2 = in7_2;

    // Cube validation
    is_cube = valid_distances && found_min && !edge_errors && !face_errors && !space_errors;
  end
endmodule