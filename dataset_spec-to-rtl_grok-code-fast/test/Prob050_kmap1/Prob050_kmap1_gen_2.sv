module TopModule(
  input reg a,
  input reg b,
  input reg c,
  output out
);
  assign out = a | b | c;
endmodule