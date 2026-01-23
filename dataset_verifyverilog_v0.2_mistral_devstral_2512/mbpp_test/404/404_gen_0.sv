module minimum (
  input signed [15:0] a,
  input signed [15:0] b,
  output signed [15:0] min_val
);

  assign min_val = (a <= b) ? a : b;

endmodule