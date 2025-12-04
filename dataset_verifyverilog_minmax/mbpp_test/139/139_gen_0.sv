module circumference_calc (
  input  [31:0] radius_i,       // Q16.16 fixed-point input
  output [31:0] circumference_o // Q16.16 fixed-point output
);
  // Multiply by 2*3.1415 = 6.283 -> 6.283 * 65536 = 411774 (rounded)
  localparam [31:0] CONST_2PI = 32'd411774;

  // 64-bit product to retain full precision, then take upper 32 bits (equivalent to >>16)
  assign circumference_o = ($signed({1'b0, radius_i}) * $signed({1'b0, CONST_2PI})) >> 16;
endmodule