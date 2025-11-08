module TopModule(
  input  a,
  input  b,
  input  c,
  input  d,
  output out_sop,
  output out_pos
);

  // Truth table:
  // a b c d | decimal | output
  // 0 0 0 0 |    0    |   0
  // 0 0 0 1 |    1    |   0
  // 0 0 1 0 |    2    |   1
  // 0 0 1 1 |    3    |   X (don't care)
  // 0 1 0 0 |    4    |   0
  // 0 1 0 1 |    5    |   0
  // 0 1 1 0 |    6    |   0
  // 0 1 1 1 |    7    |   1
  // 1 0 0 0 |    8    |   X (don't care)
  // 1 0 0 1 |    9    |   0
  // 1 0 1 0 |   10    |   0
  // 1 0 1 1 |   11    |   X (don't care)
  // 1 1 0 0 |   12    |   X (don't care)
  // 1 1 0 1 |   13    |   0
  // 1 1 1 0 |   14    |   0
  // 1 1 1 1 |   15    |   1

  // Minimum Sum-of-Products (SOP) form:
  // Output is 1 for: 2, 7, 15
  // Using K-map with don't cares at 3, 8, 11, 12:
  // Minterms: 2(0010), 7(0111), 15(1111)
  // With don't cares, we can form groups:
  // Group 1: 2,3 -> ~a~bc
  // Group 2: 7,15 -> bcd
  // Minimal SOP: ~a~bc + bcd
  assign out_sop = (~a & ~b & c) | (b & c & d);

  // Minimum Product-of-Sums (POS) form:
  // Output is 0 for: 0, 1, 4, 5, 6, 9, 10, 13, 14
  // Maxterms: 0,1,4,5,6,9,10,13,14
  // Using K-map with don't cares at 3, 8, 11, 12:
  // Group zeros and use don't cares to minimize
  // After K-map simplification:
  // POS: (b+c)(c+d)(~a+~d)
  assign out_pos = (b | c) & (c | d) & (~a | ~d);

endmodule