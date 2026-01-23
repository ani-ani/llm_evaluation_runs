module tuple_divisible_filter (
  input [7:0] tuple_0_elem_0,
  input [7:0] tuple_0_elem_1,
  input [7:0] tuple_0_elem_2,
  input [7:0] tuple_1_elem_0,
  input [7:0] tuple_1_elem_1,
  input [7:0] tuple_1_elem_2,
  input [7:0] tuple_2_elem_0,
  input [7:0] tuple_2_elem_1,
  input [7:0] tuple_2_elem_2,
  input [7:0] K,
  output [2:0] valid
);

  wire tuple_0_valid = (K != 0) && (tuple_0_elem_0 % K == 0) && (tuple_0_elem_1 % K == 0) && (tuple_0_elem_2 % K == 0);
  wire tuple_1_valid = (K != 0) && (tuple_1_elem_0 % K == 0) && (tuple_1_elem_1 % K == 0) && (tuple_1_elem_2 % K == 0);
  wire tuple_2_valid = (K != 0) && (tuple_2_elem_0 % K == 0) && (tuple_2_elem_1 % K == 0) && (tuple_2_elem_2 % K == 0);

  assign valid[0] = tuple_0_valid;
  assign valid[1] = tuple_1_valid;
  assign valid[2] = tuple_2_valid;

endmodule