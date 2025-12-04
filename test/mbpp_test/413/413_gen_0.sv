module tuple_element_extractor(
  input  [1:0]            n,
  input  [3:0][2:0][15:0] tuples,
  output [3:0][15:0]      result
);

  assign result[0] = tuples[0][n];
  assign result[1] = tuples[1][n];
  assign result[2] = tuples[2][n];
  assign result[3] = tuples[3][n];

endmodule