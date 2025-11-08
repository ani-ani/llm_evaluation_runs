module TopModule (
  input  a,
  input  b,
  input  c,
  input  d,
  output out_sop,
  output out_pos
);
  assign out_sop = (~a & ~b & c & ~d) | (b & c & d);
  assign out_pos = (a | c | d) & (c | (~d)) & (~c | d | (~b)) & (~a | b | (~c) | d);
endmodule