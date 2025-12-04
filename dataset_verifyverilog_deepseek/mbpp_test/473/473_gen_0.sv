module tuple_intersection(
  input [3:0] list1_0, list1_1, list1_2, list1_3,
  input [3:0] list1_4, list1_5, list1_6, list1_7,
  input [3:0] list2_0, list2_1, list2_2, list2_3,
  input [3:0] list2_4, list2_5, list2_6, list2_7,
  output [3:0] mask
);

  // Normalize list1 tuples
  wire [3:0] norm1_0_min = (list1_0 <= list1_1) ? list1_0 : list1_1;
  wire [3:0] norm1_0_max = (list1_0 <= list1_1) ? list1_1 : list1_0;
  
  wire [3:0] norm1_1_min = (list1_2 <= list1_3) ? list1_2 : list1_3;
  wire [3:0] norm1_1_max = (list1_2 <= list1_3) ? list1_3 : list1_2;
  
  wire [3:0] norm1_2_min = (list1_4 <= list1_5) ? list1_4 : list1_5;
  wire [3:0] norm1_2_max = (list1_4 <= list1_5) ? list1_5 : list1_4;
  
  wire [3:0] norm1_3_min = (list1_6 <= list1_7) ? list1_6 : list1_7;
  wire [3:0] norm1_3_max = (list1_6 <= list1_7) ? list1_7 : list1_6;

  // Normalize list2 tuples
  wire [3:0] norm2_0_min = (list2_0 <= list2_1) ? list2_0 : list2_1;
  wire [3:0] norm2_0_max = (list2_0 <= list2_1) ? list2_1 : list2_0;
  
  wire [3:0] norm2_1_min = (list2_2 <= list2_3) ? list2_2 : list2_3;
  wire [3:0] norm2_1_max = (list2_2 <= list2_3) ? list2_3 : list2_2;
  
  wire [3:0] norm2_2_min = (list2_4 <= list2_5) ? list2_4 : list2_5;
  wire [3:0] norm2_2_max = (list2_4 <= list2_5) ? list2_5 : list2_4;
  
  wire [3:0] norm2_3_min = (list2_6 <= list2_7) ? list2_6 : list2_7;
  wire [3:0] norm2_3_max = (list2_6 <= list2_7) ? list2_7 : list2_6;
  
  // Tuple comparisons for mask[0]
  wire match00 = (norm1_0_min == norm2_0_min) && (norm1_0_max == norm2_0_max);
  wire match01 = (norm1_0_min == norm2_1_min) && (norm1_0_max == norm2_1_max);
  wire match02 = (norm1_0_min == norm2_2_min) && (norm1_0_max == norm2_2_max);
  wire match03 = (norm1_0_min == norm2_3_min) && (norm1_0_max == norm2_3_max);
  assign mask[0] = match00 || match01 || match02 || match03;
  
  // Tuple comparisons for mask[1]
  wire match10 = (norm1_1_min == norm2_0_min) && (norm1_1_max == norm2_0_max);
  wire match11 = (norm1_1_min == norm2_1_min) && (norm1_1_max == norm2_1_max);
  wire match12 = (norm1_1_min == norm2_2_min) && (norm1_1_max == norm2_2_max);
  wire match13 = (norm1_1_min == norm2_3_min) && (norm1_1_max == norm2_3_max);
  assign mask[1] = match10 || match11 || match12 || match13;
  
  // Tuple comparisons for mask[2]
  wire match20 = (norm1_2_min == norm2_0_min) && (norm1_2_max == norm2_0_max);
  wire match21 = (norm1_2_min == norm2_1_min) && (norm1_2_max == norm2_1_max);
  wire match22 = (norm1_2_min == norm2_2_min) && (norm1_2_max == norm2_2_max);
  wire match23 = (norm1_2_min == norm2_3_min) && (norm1_2_max == norm2_3_max);
  assign mask[2] = match20 || match21 || match22 || match23;
  
  // Tuple comparisons for mask[3]
  wire match30 = (norm1_3_min == norm2_0_min) && (norm1_3_max == norm2_0_max);
  wire match31 = (norm1_3_min == norm2_1_min) && (norm1_3_max == norm2_1_max);
  wire match32 = (norm1_3_min == norm2_2_min) && (norm1_3_max == norm2_2_max);
  wire match33 = (norm1_3_min == norm2_3_min) && (norm1_3_max == norm2_3_max);
  assign mask[3] = match30 || match31 || match32 || match33;

endmodule