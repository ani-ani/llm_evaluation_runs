module TopModule (
  input reg a,
  input reg b,
  input reg c,
  output w,
  output x,
  output y,
  output z
);
  assign w = a;
  assign x = b;
  assign y = b;
  assign z = c;
endmodule