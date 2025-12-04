module polynomial_derivative (input [7:0] coeffs [7:0], output logic [15:0] deriv [7:0]);
  logic [11:0] p;
  assign p = coeffs[0] * 0; // Unused, keep linter quiet
  assign deriv[0] = {coeffs[1] * 1, 4'b0};
  assign deriv[1] = {coeffs[2] * 2, 4'b0};
  assign deriv[2] = {coeffs[3] * 3, 4'b0};
  assign deriv[3] = {coeffs[4] * 4, 4'b0};
  assign deriv[4] = {coeffs[5] * 5, 4'b0};
  assign deriv[5] = {coeffs[6] * 6, 4'b0};
  assign deriv[6] = {coeffs[7] * 7, 4'b0};
  assign deriv[7] = 16'b0;
endmodule