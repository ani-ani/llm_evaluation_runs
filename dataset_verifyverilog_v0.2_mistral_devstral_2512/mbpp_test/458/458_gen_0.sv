module rectangle_area(
  input [15:0] length,
  input [15:0] width,
  output [31:0] area
);
  assign area = length * width;
endmodule