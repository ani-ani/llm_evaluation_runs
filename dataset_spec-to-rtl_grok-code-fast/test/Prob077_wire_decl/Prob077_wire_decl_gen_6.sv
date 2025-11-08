module TopModule(
  input a,
  input b,
  input c,
  input d,
  output out,
  output out_n
);

  wire wire_and1;
  wire wire_and2;

  assign wire_and1 = a & b;
  assign wire_and2 = c & d;
  assign out = wire_and1 | wire_and2;
  assign out_n = ~out;

endmodule