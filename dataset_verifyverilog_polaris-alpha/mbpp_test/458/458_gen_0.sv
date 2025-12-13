module rectangle_area(
  input  [7:0]  l,
  input  [7:0]  b,
  output [15:0] area
);

  assign area = l * b;

endmodule