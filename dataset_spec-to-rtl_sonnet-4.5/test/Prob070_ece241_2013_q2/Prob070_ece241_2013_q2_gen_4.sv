module TopModule(
  input  a,
  input  b,
  input  c,
  input  d,
  output out_sop,
  output out_pos
);

  // Sum-of-Products (SOP) form
  // Output is 1 for: 2 (0010), 7 (0111), 15 (1111)
  // Using Karnaugh map minimization with don't cares at 3,8,11,12:
  // Minterms: m2, m7, m15
  // Don't cares: m3, m8, m11, m12
  // Minimal SOP: cd + abc
  assign out_sop = (c & d) | (a & b & c);

  // Product-of-Sums (POS) form
  // Output is 0 for: 0 (0000), 1 (0001), 4 (0100), 5 (0101), 6 (0110), 9 (1001), 10 (1010), 13 (1101), 14 (1110)
  // Using Karnaugh map minimization with don't cares at 3,8,11,12:
  // Maxterms: M0, M1, M4, M5, M6, M9, M10, M13, M14
  // Don't cares: m3, m8, m11, m12
  // Minimal POS: (c+d)(a+b+c)
  assign out_pos = (c | d) & (a | b | c);

endmodule