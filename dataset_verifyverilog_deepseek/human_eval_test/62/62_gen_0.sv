module polynomial_derivative (
  input [7:0] coeffs [7:0],
  output logic [15:0] deriv [7:0]
);
  always_comb begin
    deriv = '{default: '0};
    for (int i = 1; i <= 7; i++) begin
      deriv[i-1] = (coeffs[i] * i) << 5;
    end
  end
endmodule