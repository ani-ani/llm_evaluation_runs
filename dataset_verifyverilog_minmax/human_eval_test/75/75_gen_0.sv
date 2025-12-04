module is_multiply_prime(
  input [6:0] a,
  output logic out
);
  always_comb begin
    out = 1'b0;
    case (a)
      7'd8, 7'd12, 7'd18, 7'd20, 7'd27, 7'd28, 7'd30, 7'd42, 7'd44, 7'd45,
      7'd50, 7'd52, 7'd63, 7'd66, 7'd68, 7'd70, 7'd75, 7'd76, 7'd78:
        out = 1'b1;
      default: out = 1'b0;
    endcase
  end
endmodule
