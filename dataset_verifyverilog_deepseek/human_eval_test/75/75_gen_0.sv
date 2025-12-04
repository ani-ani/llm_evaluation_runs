module is_multiply_prime(input [6:0] a, output reg out);
  always_comb begin
    case(a)
      7'd8:    out = 1'b1;
      7'd12:   out = 1'b1;
      7'd18:   out = 1'b1;
      7'd20:   out = 1'b1;
      7'd27:   out = 1'b1;
      7'd28:   out = 1'b1;
      7'd30:   out = 1'b1;
      7'd42:   out = 1'b1;
      7'd44:   out = 1'b1;
      7'd45:   out = 1'b1;
      7'd50:   out = 1'b1;
      7'd52:   out = 1'b1;
      7'd63:   out = 1'b1;
      7'd66:   out = 1'b1;
      7'd68:   out = 1'b1;
      7'd70:   out = 1'b1;
      7'd75:   out = 1'b1;
      7'd76:   out = 1'b1;
      7'd78:   out = 1'b1;
      7'd92:   out = 1'b1;
      7'd98:   out = 1'b1;
      default: out = 1'b0;
    endcase
  end
endmodule