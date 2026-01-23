module poly_derivative(input [2:0] num_coeffs, input [15:0] xs [0:7], output reg [15:0] deriv [0:6], output reg [2:0] deriv_len);
assign deriv_len = (num_coeffs > 1) ? num_coeffs - 1 : 0;
assign deriv[0] = (deriv_len > 0) ? ((signed)xs[1] * 1) : 0;
assign deriv[1] = (deriv_len > 1) ? ((signed)xs[2] * 2) : 0;
assign deriv[2] = (deriv_len > 2) ? ((signed)xs[3] * 3) : 0;
assign deriv[3] = (deriv_len > 3) ? ((signed)xs[4] * 4) : 0;
assign deriv[4] = (deriv_len > 4) ? ((signed)xs[5] * 5) : 0;
assign deriv[5] = (deriv_len > 5) ? ((signed)xs[6] * 6) : 0;
assign deriv[6] = (deriv_len > 6) ? ((signed)xs[7] * 7) : 0;
endmodule