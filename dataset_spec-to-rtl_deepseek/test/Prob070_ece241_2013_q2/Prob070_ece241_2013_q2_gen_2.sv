module TopModule(input reg a, input reg b, input reg c, input reg d, output out_sop, output out_pos);
  assign out_sop = (~a & ~b & c) | (b & c & d);
  assign out_pos = (a | c) & (a | ~b | d) & (~a | (c & d));
endmodule