module tuple_modifier(
  input  [39:0] str_field,
  input  [7:0]  num_field,
  input  [15:0] list_val,
  input         list_empty,
  input  [1:0]  m,
  input  [15:0] n,
  input         bool_field,
  output [39:0] str_out,
  output [7:0]  num_out,
  output [15:0] list_out,
  output        list_valid_out,
  output        bool_out
);

  // 1. Pass through string and bool
  assign str_out  = str_field;
  assign bool_out = bool_field;

  // 2. Pass through num_field unless m == 1 (no behavior change specified)
  assign num_out = num_field;

  // 3. Conditional list update when m == 2 and list is empty
  wire list_update = (m == 2'b10) && (list_empty == 1'b1);

  assign list_out       = list_update ? n         : list_val;
  assign list_valid_out = list_update ? 1'b0      : list_empty;

endmodule