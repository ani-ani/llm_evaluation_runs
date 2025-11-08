module TopModule(
  output out_sop,
  output out_pos,
  input a,
  input b,
  input c,
  input d
);

  assign out_sop = (( ~a & ~b & c ) | ( b & c & d ));
  assign out_pos = (( ~c & ~d ) & ( ~c & d ) & ( a & ~b ) & ( ~a & b & c & ~d ) & ( a & b & c & ~d ));

endmodule