module add_string(
  input  [63:0] prefix_bytes,
  input  [7:0]  list [0:3],
  output [287:0] formatted_strings
);

  assign formatted_strings[ 71:  0] = {prefix_bytes, list[0]};
  assign formatted_strings[143: 72] = {prefix_bytes, list[1]};
  assign formatted_strings[215:144] = {prefix_bytes, list[2]};
  assign formatted_strings[287:216] = {prefix_bytes, list[3]};

endmodule