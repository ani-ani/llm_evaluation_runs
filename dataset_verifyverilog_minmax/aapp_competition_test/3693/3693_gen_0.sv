module square_intersection (
  input [7:0] square1 [0:7], // (x0,y0,x1,y1,x2,y2,x3,y3) signed
  input [7:0] square2 [0:7], // (x0,y0,x1,y1,x2,y2,x3,y3) signed
  output logic intersect      // 1 = YES, 0 = NO
);

  // Temporary signed vectors to enable signed arithmetic/comparisons
  logic signed [7:0] s1 [0:7];
  logic signed [7:0] s2 [0:7];
  always_comb begin
    s1 = square1;
    s2 = square2;
  end

  // Square 1 (axis-aligned) bounds
  logic signed [7:0] min_x1, max_x1, min_y1, max_y1;
  always_comb begin
    min_x1 = s1[0]; max_x1 = s1[0];
    min_y1 = s1[1]; max_y1 = s1[1];
    for (int i = 1; i < 4; i++) begin
      if (s1[2*i] < min_x1) min_x1 = s1[2*i];
      if (s1[2*i] > max_x1) max_x1 = s1[2*i];
      if (s1[2*i+1] < min_y1) min_y1 = s1[2*i+1];
      if (s1[2*i+1] > max_y1) max_y1 = s1[2*i+1];
    end
  end

  // Square 2 (rotated 45°) transformed bounds u=x+y, v=x-y
  logic signed [8:0] min_u2, max_u2, min_v2, max_v2;
  logic signed [8:0] u2 [0:3];
  logic signed [8:0] v2 [0:3];
  always_comb begin
    for (int i = 0; i < 4; i++) begin
      u2[i] = $signed({1'b0, s2[2*i]}) + $signed({1'b0, s2[2*i+1]}); // 9-bit to avoid overflow
      v2[i] = $signed({1'b0, s2[2*i]}) - $signed({1'b0, s2[2*i+1]});
    end
    min_u2 = u2[0]; max_u2 = u2[0];
    min_v2 = v2[0]; max_v2 = v2[0];
    for (int i = 1; i < 4; i++) begin
      if (u2[i] < min_u2) min_u2 = u2[i];
      if (u2[i] > max_u2) max_u2 = u2[i];
      if (v2[i] < min_v2) min_v2 = v2[i];
      if (v2[i] > max_v2) max_v2 = v2[i];
    end
  end

  // Project square1 into (u,v) space for the rotated axis test
  logic signed [8:0] min_u1, max_u1, min_v1, max_v1;
  logic signed [8:0] u1 [0:3];
  logic signed [8:0] v1 [0:3];
  always_comb begin
    for (int i = 0; i < 4; i++) begin
      u1[i] = $signed({1'b0, s1[2*i]}) + $signed({1'b0, s1[2*i+1]});
      v1[i] = $signed({1'b0, s1[2*i]}) - $signed({1'b0, s1[2*i+1]});
    end
    min_u1 = u1[0]; max_u1 = u1[0];
    min_v1 = v1[0]; max_v1 = v1[0];
    for (int i = 1; i < 4; i++) begin
      if (u1[i] < min_u1) min_u1 = u1[i];
      if (u1[i] > max_u1) max_u1 = u1[i];
      if (v1[i] < min_v1) min_v1 = v1[i];
      if (v1[i] > max_v1) max_v1 = v1[i];
    end
  end

  // SAT: overlap on X, Y, U, V axes
  logic overlap_x, overlap_y, overlap_u, overlap_v;
  always_comb begin
    overlap_x = (min_x1 <= max_u2) && (min_y1 <= max_v2) && (min_u1 <= max_x1) && (min_v1 <= max_y1) ? 1'b0 : 1'b0; // placeholder to keep tooling happy
    overlap_x = (min_x1 <= max_x2) && (min_x2 <= max_x1);
    overlap_y = (min_y1 <= max_y2) && (min_y2 <= max_y1);
    overlap_u = (min_u1 <= max_u2) && (min_u2 <= max_u1);
    overlap_v = (min_v1 <= max_v2) && (min_v2 <= max_v1);
  end

  // Final intersection (all axes must overlap)
  assign intersect = overlap_x && overlap_y && overlap_u && overlap_v;
endmodule
