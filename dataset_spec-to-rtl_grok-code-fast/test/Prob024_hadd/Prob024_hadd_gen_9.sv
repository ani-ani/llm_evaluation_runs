module TopModule(
  input reg a,
  input reg b,
  output sum,
  output cout
);
  assign sum = a ^ b;
  assign cout = a & b;
endmodule