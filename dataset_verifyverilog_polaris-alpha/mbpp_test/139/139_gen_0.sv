module circumference_calc(
  input  [31:0] radius_i,
  output [31:0] circumference_o
);

  // 64-bit product of Q16.16 radius and constant 411774 (Q16.16: 6.283)
  wire [63:0] product;
  assign product = radius_i * 32'd411774;

  // Keep upper 32 bits for Q16.16 result
  assign circumference_o = product[63:32];

endmodule