module bracket_checker(
  input  [15:0] brackets,
  output        result
);

  // Map: '<' (0) -> +1, '>' (1) -> -1
  // So contribution[i] = (brackets[i] == 0) ? +1 : -1
  wire signed [1:0]  c0  = brackets[0]  ? -1 : 1;
  wire signed [1:0]  c1  = brackets[1]  ? -1 : 1;
  wire signed [1:0]  c2  = brackets[2]  ? -1 : 1;
  wire signed [1:0]  c3  = brackets[3]  ? -1 : 1;
  wire signed [1:0]  c4  = brackets[4]  ? -1 : 1;
  wire signed [1:0]  c5  = brackets[5]  ? -1 : 1;
  wire signed [1:0]  c6  = brackets[6]  ? -1 : 1;
  wire signed [1:0]  c7  = brackets[7]  ? -1 : 1;
  wire signed [1:0]  c8  = brackets[8]  ? -1 : 1;
  wire signed [1:0]  c9  = brackets[9]  ? -1 : 1;
  wire signed [1:0]  c10 = brackets[10] ? -1 : 1;
  wire signed [1:0]  c11 = brackets[11] ? -1 : 1;
  wire signed [1:0]  c12 = brackets[12] ? -1 : 1;
  wire signed [1:0]  c13 = brackets[13] ? -1 : 1;
  wire signed [1:0]  c14 = brackets[14] ? -1 : 1;
  wire signed [1:0]  c15 = brackets[15] ? -1 : 1;

  // Prefix sums (signed). Range is [-16,16], so 6 bits are enough.
  wire signed [5:0] s0  = c0;
  wire signed [5:0] s1  = s0  + c1;
  wire signed [5:0] s2  = s1  + c2;
  wire signed [5:0] s3  = s2  + c3;
  wire signed [5:0] s4  = s3  + c4;
  wire signed [5:0] s5  = s4  + c5;
  wire signed [5:0] s6  = s5  + c6;
  wire signed [5:0] s7  = s6  + c7;
  wire signed [5:0] s8  = s7  + c8;
  wire signed [5:0] s9  = s8  + c9;
  wire signed [5:0] s10 = s9  + c10;
  wire signed [5:0] s11 = s10 + c11;
  wire signed [5:0] s12 = s11 + c12;
  wire signed [5:0] s13 = s12 + c13;
  wire signed [5:0] s14 = s13 + c14;
  wire signed [5:0] s15 = s14 + c15; // final sum after 16 positions

  // Check no prefix sum goes negative
  wire no_negative = (s0  >= 0) &&
                     (s1  >= 0) &&
                     (s2  >= 0) &&
                     (s3  >= 0) &&
                     (s4  >= 0) &&
                     (s5  >= 0) &&
                     (s6  >= 0) &&
                     (s7  >= 0) &&
                     (s8  >= 0) &&
                     (s9  >= 0) &&
                     (s10 >= 0) &&
                     (s11 >= 0) &&
                     (s12 >= 0) &&
                     (s13 >= 0) &&
                     (s14 >= 0) &&
                     (s15 >= 0);

  // Valid if final sum is 0 and no prefix sum is negative
  assign result = (s15 == 0) && no_negative;

endmodule