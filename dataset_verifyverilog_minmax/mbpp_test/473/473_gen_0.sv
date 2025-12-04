module tuple_intersection (
  // List1: 4 tuples (2 elements each, 4-bit unsigned)
  input [3:0] list1_0, list1_1, list1_2, list1_3,
  input [3:0] list1_4, list1_5, list1_6, list1_7,
  // List2: 4 tuples (2 elements each, 4-bit unsigned)
  input [3:0] list2_0, list2_1, list2_2, list2_3,
  input [3:0] list2_4, list2_5, list2_6, list2_7,
  // 4-bit mask: bit i set if normalized tuple i from list1 exists in list2
  output [3:0] mask
);
  // Normalized tuples for list1 (ensure smaller element first)
  logic [3:0] n1_0_lo, n1_0_hi;
  logic [3:0] n1_1_lo, n1_1_hi;
  logic [3:0] n1_2_lo, n1_2_hi;
  logic [3:0] n1_3_lo, n1_3_hi;
  // Normalized tuples for list2 (ensure smaller element first)
  logic [3:0] n2_0_lo, n2_0_hi;
  logic [3:0] n2_1_lo, n2_1_hi;
  logic [3:0] n2_2_lo, n2_2_hi;
  logic [3:0] n2_3_lo, n2_3_hi;

  // Normalize each tuple by sorting the two 4-bit elements
  assign n1_0_lo = (list1_0 < list1_4) ? list1_0 : list1_4;
  assign n1_0_hi = (list1_0 < list1_4) ? list1_4 : list1_0;

  assign n1_1_lo = (list1_1 < list1_5) ? list1_1 : list1_5;
  assign n1_1_hi = (list1_1 < list1_5) ? list1_5 : list1_1;

  assign n1_2_lo = (list1_2 < list1_6) ? list1_2 : list1_6;
  assign n1_2_hi = (list1_2 < list1_6) ? list1_6 : list1_2;

  assign n1_3_lo = (list1_3 < list1_7) ? list1_3 : list1_7;
  assign n1_3_hi = (list1_3 < list1_7) ? list1_7 : list1_3;

  assign n2_0_lo = (list2_0 < list2_4) ? list2_0 : list2_4;
  assign n2_0_hi = (list2_0 < list2_4) ? list2_4 : list2_0;

  assign n2_1_lo = (list2_1 < list2_5) ? list2_1 : list2_5;
  assign n2_1_hi = (list2_1 < list2_5) ? list2_5 : list2_1;

  assign n2_2_lo = (list2_2 < list2_6) ? list2_2 : list2_6;
  assign n2_2_hi = (list2_2 < list2_6) ? list2_6 : list2_2;

  assign n2_3_lo = (list2_3 < list2_7) ? list2_3 : list2_7;
  assign n2_3_hi = (list2_3 < list2_7) ? list2_7 : list2_3;

  // Parallel comparison logic for mask generation
  // Bit 0: normalized tuple 0 from list1 present in list2
  assign mask[0] = ((n1_0_lo == n2_0_lo) && (n1_0_hi == n2_0_hi)) ||
                   ((n1_0_lo == n2_1_lo) && (n1_0_hi == n2_1_hi)) ||
                   ((n1_0_lo == n2_2_lo) && (n1_0_hi == n2_2_hi)) ||
                   ((n1_0_lo == n2_3_lo) && (n1_0_hi == n2_3_hi));

  // Bit 1: normalized tuple 1 from list1 present in list2
  assign mask[1] = ((n1_1_lo == n2_0_lo) && (n1_1_hi == n2_0_hi)) ||
                   ((n1_1_lo == n2_1_lo) && (n1_1_hi == n2_1_hi)) ||
                   ((n1_1_lo == n2_2_lo) && (n1_1_hi == n2_2_hi)) ||
                   ((n1_1_lo == n2_3_lo) && (n1_1_hi == n2_3_hi));

  // Bit 2: normalized tuple 2 from list1 present in list2
  assign mask[2] = ((n1_2_lo == n2_0_lo) && (n1_2_hi == n2_0_hi)) ||
                   ((n1_2_lo == n2_1_lo) && (n1_2_hi == n2_1_hi)) ||
                   ((n1_2_lo == n2_2_lo) && (n1_2_hi == n2_2_hi)) ||
                   ((n1_2_lo == n2_3_lo) && (n1_2_hi == n2_3_hi));

  // Bit 3: normalized tuple 3 from list1 present in list2
  assign mask[3] = ((n1_3_lo == n2_0_lo) && (n1_3_hi == n2_0_hi)) ||
                   ((n1_3_lo == n2_1_lo) && (n1_3_hi == n2_1_hi)) ||
                   ((n1_3_lo == n2_2_lo) && (n1_3_hi == n2_2_hi)) ||
                   ((n1_3_lo == n2_3_lo) && (n1_3_hi == n2_3_hi));

endmodule
