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
  // 2:  a'b'cd'
  // 7:  a'bcd
  // 15: abcd
  // Using don't cares (3, 8, 11, 12) for minimization:
  // After K-map minimization with don't cares:
  // out_sop = cd + a'bc'd' + abc
  // Alternatively: cd + a'b'cd' + a'bcd + abcd
  // Simplifies to: cd (covers 3,7,11,15) is too broad
  // Better grouping: a'b'cd' + bcd + abcd
  // Minimal: a'b'cd' + bcd (covers 7,15,3,11) + ...
  // Actually minimal SOP: cd + a'b'c
  // Let me recalculate: 
  // Minterms: 2, 7, 15 with don't cares: 3, 8, 11, 12
  // Group 2,3: a'b'c
  // Group 7,15: bcd
  // Group 11,15: a_cd
  // Minimal cover: a'b'c + bcd
  assign out_sop = (~a & ~b & c) | (b & c & d);

  // Minimum Product-of-Sums (POS) form:
  // Output is 0 for: 0, 1, 4, 5, 6, 9, 10, 13, 14
  // Maxterms for zeros:
  // 0:  (a+b+c+d)
  // 1:  (a+b+c+d')
  // 4:  (a+b'+c+d)
  // 5:  (a+b'+c+d')
  // 6:  (a+b'+c'+d)
  // 9:  (a'+b+c+d')
  // 10: (a'+b+c'+d)
  // 13: (a'+b'+c+d')
  // 14: (a'+b'+c'+d)
  // After K-map minimization with don't cares:
  // Minimal POS: (b+c)(c+d')(a+c+d)
  // Actually: (c+d')(b+c)(a+b+d)
  assign out_pos = (c | ~d) & (b | c) & (a | b | d);

endmodule