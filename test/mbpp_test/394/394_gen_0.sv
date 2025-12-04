module check_distinct(
  input  [7:0] tuple [7:0],
  output       is_distinct
);

  wire dup_1_0 = (tuple[1] == tuple[0]);

  wire dup_2_0 = (tuple[2] == tuple[0]);
  wire dup_2_1 = (tuple[2] == tuple[1]);

  wire dup_3_0 = (tuple[3] == tuple[0]);
  wire dup_3_1 = (tuple[3] == tuple[1]);
  wire dup_3_2 = (tuple[3] == tuple[2]);

  wire dup_4_0 = (tuple[4] == tuple[0]);
  wire dup_4_1 = (tuple[4] == tuple[1]);
  wire dup_4_2 = (tuple[4] == tuple[2]);
  wire dup_4_3 = (tuple[4] == tuple[3]);

  wire dup_5_0 = (tuple[5] == tuple[0]);
  wire dup_5_1 = (tuple[5] == tuple[1]);
  wire dup_5_2 = (tuple[5] == tuple[2]);
  wire dup_5_3 = (tuple[5] == tuple[3]);
  wire dup_5_4 = (tuple[5] == tuple[4]);

  wire dup_6_0 = (tuple[6] == tuple[0]);
  wire dup_6_1 = (tuple[6] == tuple[1]);
  wire dup_6_2 = (tuple[6] == tuple[2]);
  wire dup_6_3 = (tuple[6] == tuple[3]);
  wire dup_6_4 = (tuple[6] == tuple[4]);
  wire dup_6_5 = (tuple[6] == tuple[5]);

  wire dup_7_0 = (tuple[7] == tuple[0]);
  wire dup_7_1 = (tuple[7] == tuple[1]);
  wire dup_7_2 = (tuple[7] == tuple[2]);
  wire dup_7_3 = (tuple[7] == tuple[3]);
  wire dup_7_4 = (tuple[7] == tuple[4]);
  wire dup_7_5 = (tuple[7] == tuple[5]);
  wire dup_7_6 = (tuple[7] == tuple[6]);

  wire has_duplicate =
      dup_1_0 |
      dup_2_0 | dup_2_1 |
      dup_3_0 | dup_3_1 | dup_3_2 |
      dup_4_0 | dup_4_1 | dup_4_2 | dup_4_3 |
      dup_5_0 | dup_5_1 | dup_5_2 | dup_5_3 | dup_5_4 |
      dup_6_0 | dup_6_1 | dup_6_2 | dup_6_3 | dup_6_4 | dup_6_5 |
      dup_7_0 | dup_7_1 | dup_7_2 | dup_7_3 | dup_7_4 | dup_7_5 | dup_7_6;

  assign is_distinct = ~has_duplicate;

endmodule