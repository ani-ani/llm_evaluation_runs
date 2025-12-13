module tuple_creator(
  input  [127:0]       test_str,
  input  [1:0][127:0]  test_list,
  output [2:0][127:0]  tuple_out
);

  assign tuple_out[0] = test_list[0];
  assign tuple_out[1] = test_list[1];
  assign tuple_out[2] = test_str;

endmodule