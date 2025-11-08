module TopModule(
  input a,
  input b,
  input c,
  input d,
  output out_sop,
  output out_pos
);

  assign out_sop = (~d & ~c & b & ~a) | (a & b & c);
  assign out_pos = ~ (( d | c | ~ b | a ) & ( ~ a | ~ b | ~ c ));
endmodule