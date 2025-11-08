module TopModule(
  input reg signed [7:0] a,
  input reg signed [7:0] b,
  output reg signed [7:0] s,
  output reg overflow
);
  assign s = a + b;
  assign overflow = (a[7] == b[7]) && (s[7] != a[7]);
endmodule