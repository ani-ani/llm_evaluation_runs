module unit_digit_multiplier(
  input  signed [11:0] a,
  input  signed [11:0] b,
  output       [7:0]  product
);

  // Absolute values
  wire [11:0] abs_a = a[11] ? (~a + 12'd1) : a;
  wire [11:0] abs_b = b[11] ? (~b + 12'd1) : b;

  // Unit digit extraction (mod 10)
  wire [3:0] unit_a = abs_a % 10;
  wire [3:0] unit_b = abs_b % 10;

  // Multiply unit digits
  assign product = unit_a * unit_b;

endmodule