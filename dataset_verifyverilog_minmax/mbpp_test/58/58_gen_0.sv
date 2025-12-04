module sign_checker (input signed [7:0] x, y, output result);
  assign result = x[7] ^ y[7];
endmodule