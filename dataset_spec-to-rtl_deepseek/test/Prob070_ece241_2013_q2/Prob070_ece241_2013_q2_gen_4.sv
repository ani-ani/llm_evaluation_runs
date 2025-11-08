module TopModule(input a, b, c, d, output out_sop, output out_pos);
  assign out_sop = (b & c & d) | (~a & ~b & c & ~d);
  assign out_pos = (a | c) & (~b | ~c | d) & (c | ~d) & (~a | b | ~c);
endmodule