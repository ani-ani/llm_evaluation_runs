module TopModule(
  input a,
  input b,
  input c,
  input d,
  output q
);
  assign q = c ? 1'b1 : (a & b);
endmodule