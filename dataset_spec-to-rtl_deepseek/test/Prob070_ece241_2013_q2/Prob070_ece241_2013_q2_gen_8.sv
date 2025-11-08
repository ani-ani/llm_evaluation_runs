module TopModule(input a, b, c, d, output out_sop, out_pos);
  assign out_sop = (~a & ~b & c & ~d) | (b & c & d);
  assign out_pos = (a | c) & (a | ~b | ~c | d) & (~a | c | ~d) & (~a | ~c | d);
endmodule