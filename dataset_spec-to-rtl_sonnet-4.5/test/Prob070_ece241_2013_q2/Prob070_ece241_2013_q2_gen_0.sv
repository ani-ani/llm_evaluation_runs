module TopModule(
  input  a,
  input  b,
  input  c,
  input  d,
  output out_sop,
  output out_pos
);

  // Truth table:
  // 0  (0000): 0
  // 1  (0001): 0
  // 2  (0010): 1
  // 3  (0011): X (don't care)
  // 4  (0100): 0
  // 5  (0101): 0
  // 6  (0110): 0
  // 7  (0111): 1
  // 8  (1000): X (don't care)
  // 9  (1001): 0
  // 10 (1010): 0
  // 11 (1011): X (don't care)
  // 12 (1100): X (don't care)
  // 13 (1101): 0
  // 14 (1110): 0
  // 15 (1111): 1

  // Minimum SOP form:
  // Using K-map with don't cares optimally placed:
  // Minterms: 2, 7, 15 with don't cares: 3, 8, 11, 12
  // SOP: cd + ac
  assign out_sop = (c & d) | (a & c);

  // Minimum POS form:
  // Maxterms for zeros: 0, 1, 4, 5, 6, 9, 10, 13, 14
  // Using K-map with don't cares optimally placed:
  // POS: (c) * (a + d)
  assign out_pos = c & (a | d);

endmodule