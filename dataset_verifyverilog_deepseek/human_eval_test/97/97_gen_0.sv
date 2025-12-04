module unit_digit_multiplier (
  input reg signed [11:0] a,
  input reg signed [11:0] b,
  output wire [7:0] product
);

wire [11:0] abs_a = a[11] ? (~a + 1) : a;
wire [11:0] abs_b = b[11] ? (~b + 1) : b;
wire [3:0] unit_a = abs_a % 10;
wire [3:0] unit_b = abs_b % 10;
assign product = unit_a * unit_b;

endmodule