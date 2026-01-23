module divisibility_hack(
  input [63:0] b,
  input [63:0] d,
  output valid
);

  wire [63:0] remainder = b % d;
  wire remainder_zero = (remainder == 0);
  wire [63:0] exponent = (d - 1) >> 1;
  wire [63:0] result;

  assign result = modular_pow(remainder, exponent, d);
  assign valid = (!remainder_zero) && (result == 1);

  function [63:0] modular_pow;
    input [63:0] base;
    input [63:0] exp;
    input [63:0] mod;
    reg [63:0] result = 1;
    reg [63:0] current_base = base;
    reg [63:0] current_exp = exp;
    begin
      while (current_exp > 0) begin
        if (current_exp[0]) begin
          result = modular_mult(result, current_base, mod);
        end
        current_base = modular_mult(current_base, current_base, mod);
        current_exp = current_exp >> 1;
      end
    end
  endfunction

  function [63:0] modular_mult;
    input [63:0] a;
    input [63:0] b;
    input [63:0] mod;
    reg [127:0] product = a * b;
    begin
      modular_mult = product % mod;
    end
  endfunction

endmodule