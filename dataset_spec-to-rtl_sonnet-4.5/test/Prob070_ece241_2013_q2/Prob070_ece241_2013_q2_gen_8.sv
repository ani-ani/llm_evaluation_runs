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

  // Minimum Sum-of-Products (SOP):
  // Output is 1 for: 2, 7, 15
  // Using K-map with don't cares at 3, 8, 11, 12:
  // Minterms: m2 + m7 + m15
  // 2:  ~a ~b  c ~d
  // 7:  ~a  b  c  d
  // 15:  a  b  c  d
  // Grouping with don't cares:
  // Group (2,3):   ~a ~b c
  // Group (7,15):  b c d
  // Minimal SOP: ~a~bc + bcd
  assign out_sop = (~a & ~b & c) | (b & c & d);

  // Minimum Product-of-Sums (POS):
  // Output is 0 for: 0, 1, 4, 5, 6, 9, 10, 13, 14
  // Using K-map with don't cares at 3, 8, 11, 12:
  // Maxterms for zeros: M0, M1, M4, M5, M6, M9, M10, M13, M14
  // 0:  (a + b + c + d)
  // 1:  (a + b + c + ~d)
  // 4:  (a + ~b + c + d)
  // 5:  (a + ~b + c + ~d)
  // 6:  (a + ~b + ~c + d)
  // 9:  (~a + b + ~c + d)
  // 10: (~a + b + ~c + ~d)
  // 13: (~a + ~b + c + d)
  // 14: (~a + ~b + c + ~d)
  // Grouping with don't cares:
  // Group (0,1,4,5): (a + c)
  // Group (6,14): (~c + d)
  // Group (9,10,13,14): (~a + ~c)
  // Minimal POS: (a+c)(~c+d)(~a+~c) which simplifies
  // Actually using K-map more carefully:
  // (c + d)(~b + ~c)(~a + ~c)
  assign out_pos = (c | d) & (~b | ~c) & (~a | ~c);

endmodule