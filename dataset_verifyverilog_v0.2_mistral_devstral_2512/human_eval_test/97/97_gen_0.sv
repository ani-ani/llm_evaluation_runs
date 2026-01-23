module multiply_unit_digits (
  input signed [7:0] a,
  input signed [7:0] b,
  output [7:0] result
);

  wire [7:0] abs_a = (a[7] == 1'b1) ? -a : a;
  wire [7:0] abs_b = (b[7] == 1'b1) ? -b : b;

  wire [3:0] digit_a = abs_a % 10;
  wire [3:0] digit_b = abs_b % 10;

  assign result = digit_a * digit_b;

endmodule