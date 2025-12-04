module sign_checker(
  input  signed [7:0] x,
  input  signed [7:0] y,
  output       result
);

  assign result = (x[7] ^ y[7]) != 1'b0;

endmodule