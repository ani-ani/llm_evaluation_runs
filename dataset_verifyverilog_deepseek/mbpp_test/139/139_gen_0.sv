module circumference_calc(
  input  [31:0] radius_i,
  output [31:0] circumference_o
);
  assign circumference_o = (radius_i * 32'd411774) [63:32];
endmodule