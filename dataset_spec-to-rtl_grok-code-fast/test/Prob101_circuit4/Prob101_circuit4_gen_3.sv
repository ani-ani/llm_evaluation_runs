module TopModule(
  input reg a,
  input reg b,
  input reg c,
  input reg d,
  output reg q
);
  assign q = b | c;
endmodule