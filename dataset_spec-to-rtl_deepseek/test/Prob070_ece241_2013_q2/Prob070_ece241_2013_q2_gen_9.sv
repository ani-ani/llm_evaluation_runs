module TopModule(input a, b, c, d, output out_sop, out_pos);
  // SOP: (b & c & d) | (~a & ~b & c)
  assign out_sop = (b & c & d) | (~a & ~b & c);
  
  // POS: (a | c) & (~a | ~c | d) & (b | c) & (~b | ~c | d)
  assign out_pos = (a | c) & (~a | ~c | d) & (b | c) & (~b | ~c | d);
endmodule