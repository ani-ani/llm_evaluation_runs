module TopModule(
  input  a,
  input  b,
  input  c,
  input  d,
  output out_sop,
  output out_pos
);

  // Input mapping: a=MSB, d=LSB
  // Logic-1 for: 2 (0010), 7 (0111), 15 (1111)
  // Logic-0 for: 0 (0000), 1 (0001), 4 (0100), 5 (0101), 6 (0110), 9 (1001), 10 (1010), 13 (1101), 14 (1110)
  // Don't care: 3 (0011), 8 (1000), 11 (1011), 12 (1100)

  // Minimum Sum-of-Products (SOP) form
  // Using K-map with don't cares to minimize:
  // f = c'd + ab + acd
  assign out_sop = (~c & d) | (a & b) | (a & c & d);

  // Minimum Product-of-Sums (POS) form
  // Using K-map with don't cares to minimize:
  // f = (a+d)(b+c+d)(a+c+d)
  assign out_pos = (a | d) & (b | c | d) & (a | c | d);

endmodule