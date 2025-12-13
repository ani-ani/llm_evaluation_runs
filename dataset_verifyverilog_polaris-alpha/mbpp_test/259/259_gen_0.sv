module tuple_maximizer(
  input  [3:0] t1_0_0, t1_0_1,
               t1_1_0, t1_1_1,
               t1_2_0, t1_2_1,
               t1_3_0, t1_3_1,
  input  [3:0] t2_0_0, t2_0_1,
               t2_1_0, t2_1_1,
               t2_2_0, t2_2_1,
               t2_3_0, t2_3_1,
  output [3:0] res_0_0, res_0_1,
               res_1_0, res_1_1,
               res_2_0, res_2_1,
               res_3_0, res_3_1
);

  assign res_0_0 = (t1_0_0 >= t2_0_0) ? t1_0_0 : t2_0_0;
  assign res_0_1 = (t1_0_1 >= t2_0_1) ? t1_0_1 : t2_0_1;

  assign res_1_0 = (t1_1_0 >= t2_1_0) ? t1_1_0 : t2_1_0;
  assign res_1_1 = (t1_1_1 >= t2_1_1) ? t1_1_1 : t2_1_1;

  assign res_2_0 = (t1_2_0 >= t2_2_0) ? t1_2_0 : t2_2_0;
  assign res_2_1 = (t1_2_1 >= t2_2_1) ? t1_2_1 : t2_2_1;

  assign res_3_0 = (t1_3_0 >= t2_3_0) ? t1_3_0 : t2_3_0;
  assign res_3_1 = (t1_3_1 >= t2_3_1) ? t1_3_1 : t2_3_1;

endmodule