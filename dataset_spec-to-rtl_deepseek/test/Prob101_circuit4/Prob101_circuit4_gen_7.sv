module TopModule(
  input reg a,
  input reg b,
  input reg c,
  input reg d,
  output q
);
  assign q = b | c;
endmodule