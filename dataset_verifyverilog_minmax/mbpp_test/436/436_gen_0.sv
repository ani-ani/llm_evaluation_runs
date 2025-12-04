module neg_nos(
  output wire signed [7:0] out0, out1, out2, out3,
  input reg signed [7:0] num0, num1, num2, num3
);

assign out0 = (num0 < 0) ? num0 : 8'b0;
assign out1 = (num1 < 0) ? num1 : 8'b0;
assign out2 = (num2 < 0) ? num2 : 8'b0;
assign out3 = (num3 < 0) ? num3 : 8'b0;

endmodule