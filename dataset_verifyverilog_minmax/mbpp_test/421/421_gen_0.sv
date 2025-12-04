module tuple_concat (
  input logic [23:0] elem1,
  input logic [23:0] elem2,
  input logic [23:0] elem3,
  input logic [23:0] elem4,
  output logic [119:0] result
);
  // Concatenate: e1[23:0] + '-' + e2[23:0] + '-' + e3[23:0] + '-' + e4[23:0]
  // Each elem is 3 bytes in big-endian order: [23:16]=char0, [15:8]=char1, [7:0]=char2
  assign result = {elem1, 8'h2D, elem2, 8'h2D, elem3, 8'h2D, elem4};
endmodule