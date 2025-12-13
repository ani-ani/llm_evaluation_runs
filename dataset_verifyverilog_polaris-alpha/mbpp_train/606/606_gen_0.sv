module degree_to_radian(
  input  [15:0] degree,
  output [31:0] radian
);

  // Multiply degree by Q16.16 representation of (pi/180) = 0x00000478 (1144)
  // Result: radian is Q16.16 fixed-point (lower 16 bits fractional)
  assign radian = degree * 32'h00000478;

endmodule