module scaled_mult_div(
  input  signed [7:0] num0,
  input  signed [7:0] num1,
  input  signed [7:0] num2,
  input  signed [7:0] num3,
  output signed [31:0] result
);

  wire signed [15:0] mult01;
  wire signed [23:0] mult012;
  wire signed [31:0] mult0123;

  assign mult01   = num0 * num1;
  assign mult012  = mult01 * num2;
  assign mult0123 = mult012 * num3;

  assign result = mult0123 >>> 2;

endmodule