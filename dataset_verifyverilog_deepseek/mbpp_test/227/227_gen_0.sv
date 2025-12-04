module min_of_three (
  input signed [7:0] a,
  input signed [7:0] b,
  input signed [7:0] c,
  output signed [7:0] min_val
);

  wire signed [7:0] min_ab = (a < b) ? a : b;
  assign min_val = (min_ab < c) ? min_ab : c;

endmodule