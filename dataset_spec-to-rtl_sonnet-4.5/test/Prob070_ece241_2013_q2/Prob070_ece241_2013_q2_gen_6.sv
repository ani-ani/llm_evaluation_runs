module TopModule(
  input  a,
  input  b,
  input  c,
  input  d,
  output out_sop,
  output out_pos
);

  // Sum-of-Products form (SOP)
  // Output is 1 for inputs: 2 (0010), 7 (0111), 15 (1111)
  // Output is 0 for inputs: 0 (0000), 1 (0001), 4 (0100), 5 (0101), 6 (0110), 9 (1001), 10 (1010), 13 (1101), 14 (1110)
  // Don't cares: 3 (0011), 8 (1000), 11 (1011), 12 (1100)
  // 
  // Minimized SOP using K-map with don't cares:
  // out_sop = a'b'cd' + bcd + abcd
  // Simplified further: out_sop = cd(b + a) + a'b'cd'
  // After K-map minimization: out_sop = cd(a + b) + a'b'cd'
  // Which simplifies to: out_sop = a'b'cd' + acd + bcd
  // Further simplified: out_sop = a'b'cd' + cd(a + b)
  // Actual minimal: out_sop = a'b'cd' + bcd + acd
  // Or: out_sop = a'b'cd' + cd(a+b)
  
  assign out_sop = (~a & ~b & c & ~d) | (a & c & d) | (b & c & d);

  // Product-of-Sums form (POS)
  // For POS, we work with the zeros and complement
  // Zeros are at: 0, 1, 4, 5, 6, 9, 10, 13, 14
  // After K-map minimization for POS:
  // out_pos = (a+b+c)(a+c+d)(b+c+d')(a'+c+d)
  // Simplified: out_pos = c(a+d)(b+d')(a'+b+d)
  // Actual minimal POS: (a+c)(b+c)(c+d)(a'+b'+c'+d')
  // More accurate: (c+a)(c+b)(d+a)(d+b)(a'+d'+...)
  // Correct minimal: (a+b+c)(a+c+d)(b+c+d')(a'+c+d)
  
  assign out_pos = (a | b | c) & (a | c | d) & (b | c | ~d) & (~a | c | d);

endmodule