module sort_sublists (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_sublists,
  input [2:0] num_strings_0,
  input [2:0] num_strings_1,
  input [2:0] num_strings_2,
  input [63:0] sublist_0_str_0, sublist_0_str_1, sublist_0_str_2, sublist_0_str_3,
  input [63:0] sublist_0_str_4, sublist_0_str_5, sublist_0_str_6, sublist_0_str_7,
  input [63:0] sublist_1_str_0, sublist_1_str_1, sublist_1_str_2, sublist_1_str_3,
  input [63:0] sublist_1_str_4