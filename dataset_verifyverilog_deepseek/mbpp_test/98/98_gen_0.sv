module scaled_mult_div (
  input reg signed [7:0] num0,
  input reg signed [7:0] num1,
  input reg signed [7:0] num2,
  input reg signed [7:0] num3,
  output reg signed [31:0] result
);
  always_comb begin
    result = (num0 * num1 * num2 * num3) >>> 2;
  end
endmodule