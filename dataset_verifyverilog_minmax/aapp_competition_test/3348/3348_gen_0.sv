module bonbon_arrangement(
  input [1:0] r,
  input [1:0] c,
  input [4:0] a,
  input [4:0] b,
  input [4:0] c_in,
  output possible
);
  // Compute total cells using integer arithmetic
  wire [5:0] total = r * c;
  // Half of total cells (floor division)
  wire [5:0] half_total = total / 6'sd2;

  // Determine if a valid arrangement is possible
  assign possible = (a <= half_total) && (b <= half_total) && (c_in <= half_total);
endmodule