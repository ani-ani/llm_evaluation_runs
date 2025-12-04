module neg_nos(
  input  signed [7:0] num0,
  input  signed [7:0] num1,
  input  signed [7:0] num2,
  input  signed [7:0] num3,
  output signed [7:0] out0,
  output signed [7:0] out1,
  output signed [7:0] out2,
  output signed [7:0] out3
);

  assign out0 = (num0 < 0) ? num0 : 8'sd0;
  assign out1 = (num1 < 0) ? num1 : 8'sd0;
  assign out2 = (num2 < 0) ? num2 : 8'sd0;
  assign out3 = (num3 < 0) ? num3 : 8'sd0;

endmodule