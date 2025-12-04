module min_finder (
  input signed [7:0] a,
  input signed [7:0] b,
  output signed [7:0] min_val
);
  assign min_val = (a <= b) ? a : b;
endmodule