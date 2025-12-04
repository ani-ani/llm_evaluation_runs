module tuple_modifier (
  input [39:0] str_field,
  input [7:0] num_field,
  input [15:0] list_val,
  input list_empty,
  input [1:0] m,
  input [15:0] n,
  input bool_field,
  output [39:0] str_out,
  output [7:0] num_out,
  output [15:0] list_out,
  output list_valid_out,
  output bool_out
);
  assign str_out = str_field;
  assign bool_out = bool_field;
  assign num_out = num_field;
  assign list_out = (m == 2'd2 && list_empty) ? n : list_val;
  assign list_valid_out = (m == 2'd2 && list_empty) ? 1'b0 : list_empty;
endmodule