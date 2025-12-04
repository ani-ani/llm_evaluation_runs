module square_intersection(square1, square2, intersect);
  input [7:0] square1 [0:7];
  input [7:0] square2 [0:7];
  output intersect;
  
  wire signed [7:0] s1x0 = square1[0];
  wire signed [7:0] s1x1 = square1[2];
  wire signed [7:0] s1x2 = square1[4];
  wire signed [7:0] s1x3 = square1[6];
  
  wire signed [7:0] s1y0 = square1[1];
  wire signed [7:0] s1y1 = square1[3];
  wire signed [7:0] s1y2 = square1[5];
  wire signed [7:0] s1y3 = square1[7];
  
  wire signed [7:0] s1_min_x01 = (s1x0 < s1x1) ? s1x0 : s1x1;
  wire signed [7:0] s1_min_x23 = (s1x2 < s1x3) ? s1x2 : s1x3;
  wire signed [7:0] min_x1 = (s1_min_x01 < s1_min_x23) ? s1_min_x01 : s1_min_x23;
  
  wire signed [7:0] s1_max_x01 = (s1x0 > s1x1) ? s1x0 : s1x1;
  wire signed [7:0] s1_max_x23 = (s1x2 > s1x3) ? s1x2 : s1x3;
  wire signed [7:0] max_x1 = (s1_max_x01 > s1_max_x23) ? s1_max_x01 : s1_max_x23;
  
  wire signed [7:0] s1_min_y01 = (s1y0 < s1y1) ? s1y0 : s1y1;
  wire signed [7:0] s1_min_y23 = (s1y2 < s1y3) ? s1y2 : s1y3;
  wire signed [7:0] min_y1 = (s1_min_y01 < s1_min_y23) ? s1_min_y01 : s1_min_y23;
  
  wire signed [7:0] s1_max_y01 = (s1y0 > s1y1) ? s1y0 : s1y1;
  wire signed [7:0] s1_max_y23 = (s1y2 > s1y3) ? s1y2 : s1y3;
  wire signed [7:0] max_y1 = (s1_max_y01 > s1_max_y23) ? s1_max_y01 : s1_max_y23;
  
  wire signed [7:0] s2x0 = square2[0];
  wire signed [7:0] s2x1 = square2[2];
  wire signed [7:0] s2x2 = square2[4];
  wire signed [7:0] s2x3 = square2[6];
  
  wire signed [7:0] s2y0 = square2[1];
  wire signed [7:0] s2y1 = square2[3];
  wire signed [7:0] s2y2 = square2[5];
  wire signed [7:0] s2y3 = square2[7];
  
  wire signed [7:0] s2_min_x01 = (s2x0 < s2x1) ? s2x0 : s2x1;
  wire signed [7:0] s2_min_x23 = (s2x2 < s2x3) ? s2x2 : s2x3;
  wire signed [7:0] min_x2 = (s2_min_x01 < s2_min_x23) ? s2_min_x01 : s2_min_x23;
  
  wire signed [7:0] s2_max_x01 = (s2x0 > s2x1) ? s2x0 : s2x1;
  wire signed [7:0] s2_max_x23 = (s2x2 > s2x3) ? s2x2 : s2x3;
  wire signed [7:0] max_x2 = (s2_max_x01 > s2_max_x23) ? s2_max_x01 : s2_max_x23;
  
  wire signed [7:0] s2_min_y01 = (s2y0 < s2y1) ? s2y0 : s2y1;
  wire signed [7:0] s2_min_y23 = (s2y2 < s2y3) ? s2y2 : s2y3;
  wire signed [7:0] min_y2 = (s2_min_y01 < s2_min_y23) ? s2_min_y01 : s2_min_y23;
  
  wire signed [7:0] s2_max_y01 = (s2y0 > s2y1) ? s2y0 : s2y1;
  wire signed [7:0] s2_max_y23 = (s2y2 > s2y3) ? s2y2 : s2y3;
  wire signed [7:0] max_y2 = (s2_max_y01 > s2_max_y23) ? s2_max_y01 : s2_max_y23;
  
  wire signed [8:0] s1_u0 = $signed(square1[0]) + $signed(square1[1]);
  wire signed [8:0] s1_v0 = $signed(square1[0]) - $signed(square1[1]);
  wire signed [8:0] s1_u1 = $signed(square1[2]) + $signed(square1[3]);
  wire signed [8:0] s1_v1 = $signed(square1[2]) - $signed(square1[3]);
  wire signed [8:0] s1_u2 = $signed(square1[4]) + $signed(square1[5]);
  wire signed [8:0] s1_v2 = $signed(square1[4]) - $signed(square1[5]);
  wire signed [8:0] s1_u3 = $signed(square1[6]) + $signed(square1[7]);
  wire signed [8:0] s1_v3 = $signed(square1[6]) - $signed(square1[7]);
  
  wire signed [8:0] s1_min_u01 = (s1_u0 < s1_u1) ? s1_u0 : s1_u1;
  wire signed [8:0] s1_min_u23 = (s1_u2 < s1_u3) ? s1_u2 : s1_u3;
  wire signed [8:0] min_u1 = (s1_min_u01 < s1_min_u23) ? s1_min_u01 : s1_min_u23;
  
  wire signed [8:0] s1_max_u01 = (s1_u0 > s1_u1) ? s1_u0 : s1_u1;
  wire signed [8:0] s1_max_u23 = (s1_u2 > s1_u3) ? s1_u2 : s1_u3;
  wire signed [8:0] max_u1 = (s1_max_u01 > s1_max_u23) ? s1_max_u01 : s1_max_u23;
  
  wire signed [8:0] s1_min_v01 = (s1_v0 < s1_v1) ? s1_v0 : s1_v1;
  wire signed [8:0] s1_min_v23 = (s1_v2 < s1_v3) ? s1_v2 : s1_v3;
  wire signed [8:0] min_v1 = (s1_min_v01 < s1_min_v23) ? s1_min_v01 : s1_min_v23;
  
  wire signed [8:0] s1_max_v01 = (s1_v0 > s1_v1) ? s1_v0 : s1_v1;
  wire signed [8:0] s1_max_v23 = (s1_v2 > s1_v3) ? s1_v2 : s1_v3;
  wire signed [8:0] max_v1 = (s1_max_v01 > s1_max_v23) ? s1_max_v01 : s1_max_v23;
  
  wire signed [8:0] s2_u0 = $signed(square2[0]) + $signed(square2[1]);
  wire signed [8:0] s2_v0 = $signed(square2[0]) - $signed(square2[1]);
  wire signed [8:0] s2_u1 = $signed(square2[2]) + $signed(square2[3]);
  wire signed [8:0] s2_v1 = $signed(square2[2]) - $signed(square2[3]);
  wire signed [8:0] s2_u2 = $signed(square2[4]) + $signed(square2[5]);
  wire signed [8:0] s2_v2 = $signed(square2[4]) - $signed(square2[5]);
  wire signed [8:0] s2_u3 = $signed(square2[6]) + $signed(square2[7]);
  wire signed [8:0] s2_v3 = $signed(square2[6]) - $signed(square2[7]);
  
  wire signed [8:0] s2_min_u01 = (s2_u0 < s2_u1) ? s2_u0 : s2_u1;
  wire signed [8:0] s2_min_u23 = (s2_u2 < s2_u3) ? s2_u2 : s2_u3;
  wire signed [8:0] min_u2 = (s2_min_u01 < s2_min_u23) ? s2_min_u01 : s2_min_u23;
  
  wire signed [8:0] s2_max_u01 = (s2_u0 > s2_u1) ? s2_u0 : s2_u1;
  wire signed [8:0] s2_max_u23 = (s2_u2 > s2_u3) ? s2_u2 : s2_u3;
  wire signed [8:0] max_u2 = (s2_max_u01 > s2_max_u23) ? s2_max_u01 : s2_max_u23;
  
  wire signed [8:0] s2_min_v01 = (s2_v0 < s2_v1) ? s2_v0 : s2_v1;
  wire signed [8:0] s2_min_v23 = (s2_v2 < s2_v3) ? s2_v2 : s2_v3;
  wire signed [8:0] min_v2 = (s2_min_v01 < s2_min_v23) ? s2_min_v01 : s2_min_v23;
  
  wire signed [8:0] s2_max_v01 = (s2_v0 > s2_v1) ? s2_v0 : s2_v1;
  wire signed [8:0] s2_max_v23 = (s2_v2 > s2_v3) ? s2_v2 : s2_v3;
  wire signed [8:0] max_v2 = (s2_max_v01 > s2_max_v23) ? s2_max_v01 : s2_max_v23;
  
  wire x_overlap = (min_x1 <= max_x2) && (max_x1 >= min_x2);
  wire y_overlap = (min_y1 <= max_y2) && (max_y1 >= min_y2);
  wire u_overlap = (min_u1 <= max_u2) && (max_u1 >= min_u2);
  wire v_overlap = (min_v1 <= max_v2) && (max_v1 >= min_v2);
  
  assign intersect = x_overlap && y_overlap && u_overlap && v_overlap;
endmodule