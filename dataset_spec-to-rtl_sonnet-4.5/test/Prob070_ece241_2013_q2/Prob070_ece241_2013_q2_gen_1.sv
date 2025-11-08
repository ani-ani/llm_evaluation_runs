module TopModule(
  input  a,
  input  b,
  input  c,
  input  d,
  output out_sop,
  output out_pos
);

  // Function outputs:
  // 1 for: 2 (0010), 7 (0111), 15 (1111)
  // 0 for: 0 (0000), 1 (0001), 4 (0100), 5 (0101), 6 (0110), 9 (1001), 10 (1010), 13 (1101), 14 (1110)
  // Don't care: 3 (0011), 8 (1000), 11 (1011), 12 (1100)
  
  // Karnaugh map analysis:
  // abcd: 0000=0, 0001=0, 0010=1, 0011=X
  //       0100=0, 0101=0, 0110=0, 0111=1
  //       1000=X, 1001=0, 1010=0, 1011=X
  //       1100=X, 1101=0, 1110=0, 1111=1
  
  // Minimum SOP (sum-of-products):
  // Using don't cares to minimize:
  // Group 1s and don't cares optimally
  // After K-map minimization: cd + abc
  assign out_sop = (c & d) | (a & b & c);
  
  // Minimum POS (product-of-sums):
  // Using don't cares to minimize:
  // After K-map minimization: (c)(a+b+d)
  assign out_pos = (c) & (a | b | d);

endmodule