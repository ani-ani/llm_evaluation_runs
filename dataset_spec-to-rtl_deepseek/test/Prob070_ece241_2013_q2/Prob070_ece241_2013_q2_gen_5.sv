module TopModule(
  input wire a,
  input wire b,
  input wire c,
  input wire d,
  output logic out_sop,
  output logic out_pos
);
  assign out_sop = (~d & ~c & b) | (b & c & a);
  assign out_pos = b & (c | d | a) & (c | ~d | ~a) & (~c | d | a) & (~c | ~d | ~a);
endmodule