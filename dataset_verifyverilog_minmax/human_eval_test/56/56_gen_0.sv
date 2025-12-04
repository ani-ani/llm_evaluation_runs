module bracket_checker (
  input  [15:0] brackets,
  output       result
);

  // Compute prefix balances in parallel using 5-bit vectors (range -16..+16)
  wire [4:0] s0 = 5'd0                       + (brackets[0]  ? -5'd1 : 5'd1);
  wire [4:0] s1 = s0                         + (brackets[1]  ? -5'd1 : 5'd1);
  wire [4:0] s2 = s1                         + (brackets[2]  ? -5'd1 : 5'd1);
  wire [4:0] s3 = s2                         + (brackets[3]  ? -5'd1 : 5'd1);
  wire [4:0] s4 = s3                         + (brackets[4]  ? -5'd1 : 5'd1);
  wire [4:0] s5 = s4                         + (brackets[5]  ? -5'd1 : 5'd1);
  wire [4:0] s6 = s5                         + (brackets[6]  ? -5'd1 : 5'd1);
  wire [4:0] s7 = s6                         + (brackets[7]  ? -5'd1 : 5'd1);
  wire [4:0] s8 = s7                         + (brackets[8]  ? -5'd1 : 5'd1);
  wire [4:0] s9 = s8                         + (brackets[9]  ? -5'd1 : 5'd1);
  wire [4:0] s10 = s9                        + (brackets[10] ? -5'd1 : 5'd1);
  wire [4:0] s11 = s10                       + (brackets[11] ? -5'd1 : 5'd1);
  wire [4:0] s12 = s11                       + (brackets[12] ? -5'd1 : 5'd1);
  wire [4:0] s13 = s12                       + (brackets[13] ? -5'd1 : 5'd1);
  wire [4:0] s14 = s13                       + (brackets[14] ? -5'd1 : 5'd1);
  wire [4:0] s15 = s14                       + (brackets[15] ? -5'd1 : 5'd1);

  // Check that all prefix sums are non-negative and the final sum is zero
  assign result = (s0 >= 0) & (s1 >= 0) & (s2 >= 0) & (s3 >= 0) &
                  (s4 >= 0) & (s5 >= 0) & (s6 >= 0) & (s7 >= 0) &
                  (s8 >= 0) & (s9 >= 0) & (s10 >= 0) & (s11 >= 0) &
                  (s12 >= 0) & (s13 >= 0) & (s14 >= 0) & (s15 >= 0) &
                  (s15 == 0);

endmodule
