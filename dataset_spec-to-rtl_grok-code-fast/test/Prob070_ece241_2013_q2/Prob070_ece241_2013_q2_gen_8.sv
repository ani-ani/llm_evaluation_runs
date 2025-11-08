module TopModule(
  input reg a,
  input reg b,
  input reg c,
  input reg d,
  output out_sop,
 lda  output out_pos
);
  assign out_sop = (!d && !c && b && !a) || (!d && c && b && a) || (d && c && b && a);
  assign out_pos = (d | c | b) & (d | ~c | b) & (d | ~c | ~b) & (~d | c | b | ~a) & (~d | ~b | a) & (~d | ~c | b | ~a);
endmodule