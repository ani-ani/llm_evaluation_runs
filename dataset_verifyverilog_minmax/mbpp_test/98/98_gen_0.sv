module scaled_mult_div(
  input reg signed [7:0] num0,
  input reg signed [7:0] num1,
  input reg signed [7:0] num2,
  input reg signed [7:0] num3,
  output reg signed [31:0] result
);
  assign result = ($signed(num0) * $signed(num1) * $signed(num2) * $signed(num3)) >>> 2;
endmodule