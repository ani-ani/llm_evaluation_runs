module sum_digits_binary (
  input [13:0] N,
  output logic [5:0] sum_bin
);

  // Compute sum of decimal digits of N using modulus/division
  always_comb begin
    int unsigned n;
    int unsigned s;
    n = N;  // cast to unsigned integer for division/modulus
    s = 0;
    while (n > 0) begin
      s += n % 10;
      n /= 10;
    end
    sum_bin = s;  // s <= 36 fits in 6 bits
  end

endmodule