module castle_danger_checker (
  input [31:0] n1_x, n1_y,
  input [31:0] n2_x, n2_y,
  input [31:0] n3_x, n3_y,
  input [31:0] n4_x, n4_y,
  input [31:0] c1_x, c1_y,
  input [31:0] c2_x, c2_y,
  input [31:0] c3_x, c3_y,
  input [31:0] c4_x, c4_y,
  output [3:0] danger
);

  // Function to compute orientation (cross product)
  function [31:0] orientation;
    input [31:0] ax, ay, bx, by, cx, cy;
    begin
      orientation = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
    end
  endfunction

  // Function to check if a point is inside or on the quadrilateral
  function [3:0] check_castles;
    input [31:0] n1_x, n1_y;
    input [31:0] n2_x, n2_y;
    input [31:0] n3_x, n3_y;
    input [31:0] n4_x, n4_y;
    input [31:0] c1_x, c1_y;
    input [31:0] c2_x, c2_y;
    input [31:0] c3_x, c3_y;
    input [31:0] c4_x, c4_y;
    reg [3:0] result;
    reg [31:0] o1, o2, o3, o4;
    reg [31:0] o1_c1, o2_c1, o3_c1, o4_c1;
    reg [31:0] o1_c2, o2_c2, o3_c2, o4_c2;
    reg [31:0] o1_c3, o2_c3, o3_c3, o4_c3;
    reg [31:0] o1_c4, o2_c4, o3_c4, o4_c4;
    reg sign1, sign2, sign3, sign4;
    reg all_non_neg, all_non_pos;

    // Compute orientations for edges (n1->n2, n2->n3, n3->n4, n4->n1)
    o1 = orientation(n1_x, n1_y, n2_x, n2_y, n3_x, n3_y);
    o2 = orientation(n2_x, n2_y, n3_x, n3_y, n4_x, n4_y);
    o3 = orientation(n3_x, n3_y, n4_x, n4_y, n1_x, n1_y);
    o4 = orientation(n4_x, n4_y, n1_x, n1_y, n2_x, n2_y);

    // Determine the expected sign for the quadrilateral (convex)
    sign1 = o1[31];
    sign2 = o2[31];
    sign3 = o3[31];
    sign4 = o4[31];

    // Check if all orientations have the same sign (convex quadrilateral)
    all_non_neg = (sign1 == 0 || sign1 == 0) && (sign2 == 0 || sign2 == 0) && (sign3 == 0 || sign3 == 0) && (sign4 == 0 || sign4 == 0);
    all_non_pos = (sign1 == 1 || sign1 == 1) && (sign2 == 1 || sign2 == 1) && (sign3 == 1 || sign3 == 1) && (sign4 == 1 || sign4 == 1);

    // Compute orientations for each castle
    o1_c1 = orientation(n1_x, n1_y, n2_x, n2_y, c1_x, c1_y);
    o2_c1 = orientation(n2_x, n2_y, n3_x, n3_y, c1_x, c1_y);
    o3_c1 = orientation(n3_x, n3_y, n4_x, n4_y, c1_x, c1_y);
    o4_c1 = orientation(n4_x, n4_y, n1_x, n1_y, c1_x, c1_y);

    o1_c2 = orientation(n1_x, n1_y, n2_x, n2_y, c2_x, c2_y);
    o2_c2 = orientation(n2_x, n2_y, n3_x, n3_y, c2_x, c2_y);
    o3_c2 = orientation(n3_x, n3_y, n4_x, n4_y, c2_x, c2_y);
    o4_c2 = orientation(n4_x, n4_y, n1_x, n1_y, c2_x, c2_y);

    o1_c3 = orientation(n1_x, n1_y, n2_x, n2_y, c3_x, c3_y);
    o2_c3 = orientation(n2_x, n2_y, n3_x, n3_y, c3_x, c3_y);
    o3_c3 = orientation(n3_x, n3_y, n4_x, n4_y, c3_x, c3_y);
    o4_c3 = orientation(n4_x, n4_y, n1_x, n1_y, c3_x, c3_y);

    o1_c4 = orientation(n1_x, n1_y, n2_x, n2_y, c4_x, c4_y);
    o2_c4 = orientation(n2_x, n2_y, n3_x, n3_y, c4_x, c4_y);
    o3_c4 = orientation(n3_x, n3_y, n4_x, n4_y, c4_x, c4_y);
    o4_c4 = orientation(n4_x, n4_y, n1_x, n1_y, c4_x, c4_y);

    // Check if all orientations for each castle match the expected sign
    result[0] = (all_non_neg && (o1_c1[31] == 0 || o1_c1[31] == 0) && (o2_c1[31] == 0 || o2_c1[31] == 0) && (o3_c1[31] == 0 || o3_c1[31] == 0) && (o4_c1[31] == 0 || o4_c1[31] == 0)) ||
                (all_non_pos && (o1_c1[31] == 1 || o1_c1[31] == 1) && (o2_c1[31] == 1 || o2_c1[31] == 1) && (o3_c1[31] == 1 || o3_c1[31] == 1) && (o4_c1[31] == 1 || o4_c1[31] == 1)) ||
                (o1_c1 == 0 || o2_c1 == 0 || o3_c1 == 0 || o4_c1 == 0);

    result[1] = (all_non_neg && (o1_c2[31] == 0 || o1_c2[31] == 0) && (o2_c2[31] == 0 || o2_c2[31] == 0) && (o3_c2[31] == 0 || o3_c2[31] == 0) && (o4_c2[31] == 0 || o4_c2[31] == 0)) ||
                (all_non_pos && (o1_c2[31] == 1 || o1_c2[31] == 1) && (o2_c2[31] == 1 || o2_c2[31] == 1) && (o3_c2[31] == 1 || o3_c2[31] == 1) && (o4_c2[31] == 1 || o4_c2[31] == 1)) ||
                (o1_c2 == 0 || o2_c2 == 0 || o3_c2 == 0 || o4_c2 == 0);

    result[2] = (all_non_neg && (o1_c3[31] == 0 || o1_c3[31] == 0) && (o2_c3[31] == 0 || o2_c3[31] == 0) && (o3_c3[31] == 0 || o3_c3[31] == 0) && (o4_c3[31] == 0 || o4_c3[31] == 0)) ||
                (all_non_pos && (o1_c3[31] == 1 || o1_c3[31] == 1) && (o2_c3[31] == 1 || o2_c3[31] == 1) && (o3_c3[31] == 1 || o3_c3[31] == 1) && (o4_c3[31] == 1 || o4_c3[31] == 1)) ||
                (o1_c3 == 0 || o2_c3 == 0 || o3_c3 == 0 || o4_c3 == 0);

    result[3] = (all_non_neg && (o1_c4[31] == 0 || o1_c4[31] == 0) && (o2_c4[31] == 0 || o2_c4[31] == 0) && (o3_c4[31] == 0 || o3_c4[31] == 0) && (o4_c4[31] == 0 || o4_c4[31] == 0)) ||
                (all_non_pos && (o1_c4[31] == 1 || o1_c4[31] == 1) && (o2_c4[31] == 1 || o2_c4[31] == 1) && (o3_c4[31] == 1 || o3_c4[31] == 1) && (o4_c4[31] == 1 || o4_c4[31] == 1)) ||
                (o1_c4 == 0 || o2_c4 == 0 || o3_c4 == 0 || o4_c4 == 0);

    check_castles = result;
  endfunction

  assign danger = check_castles(n1_x, n1_y, n2_x, n2_y, n3_x, n3_y, n4_x, n4_y, c1_x, c1_y, c2_x, c2_y, c3_x, c3_y, c4_x, c4_y);

endmodule