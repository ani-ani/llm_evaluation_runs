module below_threshold(
  input [7:0] threshold,
  input [3:0][7:0] l,
  output result
);

  assign result = (l[0] < threshold) &&
                 (l[1] < threshold) &&
                 (l[2] < threshold) &&
                 (l[3] < threshold);

endmodule