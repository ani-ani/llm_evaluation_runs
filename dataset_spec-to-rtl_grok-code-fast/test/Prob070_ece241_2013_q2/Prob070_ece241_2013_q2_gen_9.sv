module TopModule(input a, input b, input c, input d, output out_sop, output out_pos);
  assign out_sop = (~a & ~b & d) | (b & c & d);
  assign out_pos = (a | (~b)) & ((~a) | b) & (a | b) & ((~a) | (~b)) & ((~a) | (~b) | c);
endmodule