module TopModule(
  input a,
  input b,
  input c,
  input d,
  output out_sop,
  output out_pos
);
  assign out_sop = c & ((~a & ~b & ~d) | (b & d));
  assign out_pos = c & (~((a | b | d) & (~b | ~d)));
endmodule