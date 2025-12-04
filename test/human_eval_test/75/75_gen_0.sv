module is_multiply_prime(
  input  [6:0] a,
  output       out
);

  assign out = (a == 7'd8)  ||
               (a == 7'd12) ||
               (a == 7'd18) ||
               (a == 7'd20) ||
               (a == 7'd27) ||
               (a == 7'd28) ||
               (a == 7'd30) ||
               (a == 7'd42) ||
               (a == 7'd44) ||
               (a == 7'd45) ||
               (a == 7'd50) ||
               (a == 7'd52) ||
               (a == 7'd63) ||
               (a == 7'd66) ||
               (a == 7'd68) ||
               (a == 7'd70) ||
               (a == 7'd75) ||
               (a == 7'd76) ||
               (a == 7'd78) ||
               (a == 7'd92) ||
               (a == 7'd98);

endmodule