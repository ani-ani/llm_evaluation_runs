module triangle_area (
  input [31:0] a,
  input [31:0] h,
  output [31:0] area
);

  wire [63:0] product;
  assign product = $signed(a) * $signed(h);
  assign area = product[63:32];

endmodule