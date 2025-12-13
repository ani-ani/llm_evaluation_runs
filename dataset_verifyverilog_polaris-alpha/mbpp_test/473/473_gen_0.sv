module tuple_intersection(
  input  [3:0] list1_0,
  input  [3:0] list1_1,
  input  [3:0] list1_2,
  input  [3:0] list1_3,
  input  [3:0] list1_4,
  input  [3:0] list1_5,
  input  [3:0] list1_6,
  input  [3:0] list1_7,
  input  [3:0] list2_0,
  input  [3:0] list2_1,
  input  [3:0] list2_2,
  input  [3:0] list2_3,
  input  [3:0] list2_4,
  input  [3:0] list2_5,
  input  [3:0] list2_6,
  input  [3:0] list2_7,
  output [3:0] mask
);

  // Normalize list1 tuples
  wire [3:0] l1_01_min = (list1_0 <= list1_1) ? list1_0 : list1_1;
  wire [3:0] l1_01_max = (list1_0 <= list1_1) ? list1_1 : list1_0;

  wire [3:0] l1_23_min = (list1_2 <= list1_3) ? list1_2 : list1_3;
  wire [3:0] l1_23_max = (list1_2 <= list1_3) ? list1_3 : list1_2;

  wire [3:0] l1_45_min = (list1_4 <= list1_5) ? list1_4 : list1_5;
  wire [3:0] l1_45_max = (list1_4 <= list1_5) ? list1_5 : list1_4;

  wire [3:0] l1_67_min = (list1_6 <= list1_7) ? list1_6 : list1_7;
  wire [3:0] l1_67_max = (list1_6 <= list1_7) ? list1_7 : list1_6;

  // Normalize list2 tuples
  wire [3:0] l2_01_min = (list2_0 <= list2_1) ? list2_0 : list2_1;
  wire [3:0] l2_01_max = (list2_0 <= list2_1) ? list2_1 : list2_0;

  wire [3:0] l2_23_min = (list2_2 <= list2_3) ? list2_2 : list2_3;
  wire [3:0] l2_23_max = (list2_2 <= list2_3) ? list2_3 : list2_2;

  wire [3:0] l2_45_min = (list2_4 <= list2_5) ? list2_4 : list2_5;
  wire [3:0] l2_45_max = (list2_4 <= list2_5) ? list2_5 : list2_4;

  wire [3:0] l2_67_min = (list2_6 <= list2_7) ? list2_6 : list2_7;
  wire [3:0] l2_67_max = (list2_6 <= list2_7) ? list2_7 : list2_6;

  // Compare normalized tuples in parallel
  wire match0 = ((l1_01_min == l2_01_min) && (l1_01_max == l2_01_max)) ||
                ((l1_01_min == l2_23_min) && (l1_01_max == l2_23_max)) ||
                ((l1_01_min == l2_45_min) && (l1_01_max == l2_45_max)) ||
                ((l1_01_min == l2_67_min) && (l1_01_max == l2_67_max));

  wire match1 = ((l1_23_min == l2_01_min) && (l1_23_max == l2_01_max)) ||
                ((l1_23_min == l2_23_min) && (l1_23_max == l2_23_max)) ||
                ((l1_23_min == l2_45_min) && (l1_23_max == l2_45_max)) ||
                ((l1_23_min == l2_67_min) && (l1_23_max == l2_67_max));

  wire match2 = ((l1_45_min == l2_01_min) && (l1_45_max == l2_01_max)) ||
                ((l1_45_min == l2_23_min) && (l1_45_max == l2_23_max)) ||
                ((l1_45_min == l2_45_min) && (l1_45_max == l2_45_max)) ||
                ((l1_45_min == l2_67_min) && (l1_45_max == l2_67_max));

  wire match3 = ((l1_67_min == l2_01_min) && (l1_67_max == l2_01_max)) ||
                ((l1_67_min == l2_23_min) && (l1_67_max == l2_23_max)) ||
                ((l1_67_min == l2_45_min) && (l1_67_max == l2_45_max)) ||
                ((l1_67_min == l2_67_min) && (l1_67_max == l2_67_max));

  assign mask = {match3, match2, match1, match0};

endmodule