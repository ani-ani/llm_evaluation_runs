module TopModule(
  input logic signed [7:0] a,
  input logic signed [7:0] b,
  output logic signed [7:0] s,
  output logic overflow
);
  logic signed [8:0] full_sum;
  assign full_sum = a + b;
  assign s = full_sum[7:0];
  assign overflow = (a[7] == b[7]) && (a[7] != full_sum[7]);
endmodule