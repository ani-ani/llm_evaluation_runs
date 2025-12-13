module pairs_sum_to_zero(
  input  [5:0] l_0,
  input  [5:0] l_1,
  input  [5:0] l_2,
  input  [5:0] l_3,
  input  [5:0] l_4,
  input  [5:0] l_5,
  input  [5:0] l_6,
  input  [5:0] l_7,
  output       out
);

  // Treat inputs as signed and check all distinct pairs for sum == 0
  assign out =
       ($signed(l_0) + $signed(l_1) == 0) |
       ($signed(l_0) + $signed(l_2) == 0) |
       ($signed(l_0) + $signed(l_3) == 0) |
       ($signed(l_0) + $signed(l_4) == 0) |
       ($signed(l_0) + $signed(l_5) == 0) |
       ($signed(l_0) + $signed(l_6) == 0) |
       ($signed(l_0) + $signed(l_7) == 0) |
       ($signed(l_1) + $signed(l_2) == 0) |
       ($signed(l_1) + $signed(l_3) == 0) |
       ($signed(l_1) + $signed(l_4) == 0) |
       ($signed(l_1) + $signed(l_5) == 0) |
       ($signed(l_1) + $signed(l_6) == 0) |
       ($signed(l_1) + $signed(l_7) == 0) |
       ($signed(l_2) + $signed(l_3) == 0) |
       ($signed(l_2) + $signed(l_4) == 0) |
       ($signed(l_2) + $signed(l_5) == 0) |
       ($signed(l_2) + $signed(l_6) == 0) |
       ($signed(l_2) + $signed(l_7) == 0) |
       ($signed(l_3) + $signed(l_4) == 0) |
       ($signed(l_3) + $signed(l_5) == 0) |
       ($signed(l_3) + $signed(l_6) == 0) |
       ($signed(l_3) + $signed(l_7) == 0) |
       ($signed(l_4) + $signed(l_5) == 0) |
       ($signed(l_4) + $signed(l_6) == 0) |
       ($signed(l_4) + $signed(l_7) == 0) |
       ($signed(l_5) + $signed(l_6) == 0) |
       ($signed(l_5) + $signed(l_7) == 0) |
       ($signed(l_6) + $signed(l_7) == 0);

endmodule