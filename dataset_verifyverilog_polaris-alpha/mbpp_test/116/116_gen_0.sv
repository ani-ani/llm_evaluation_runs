module tuple_to_int(
  input  [15:0] digits,
  output [13:0] result
);

  wire [3:0] d0 = digits[3:0];
  wire [3:0] d1 = digits[7:4];
  wire [3:0] d2 = digits[11:8];
  wire [3:0] d3 = digits[15:12];

  assign result = (d3 * 14'd1000) + (d2 * 14'd100) + (d1 * 14'd10) + d0;

endmodule