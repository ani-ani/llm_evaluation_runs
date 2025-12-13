module polynomial_derivative(
    input  [7:0]  coeffs [7:0],
    output [15:0] deriv  [7:0]
);

    // Constant term ignored; deriv[7] unused
    assign deriv[0] = coeffs[1] * 16'd1;
    assign deriv[1] = coeffs[2] * 16'd2;
    assign deriv[2] = coeffs[3] * 16'd3;
    assign deriv[3] = coeffs[4] * 16'd4;
    assign deriv[4] = coeffs[5] * 16'd5;
    assign deriv[5] = coeffs[6] * 16'd6;
    assign deriv[6] = coeffs[7] * 16'd7;
    assign deriv[7] = 16'd0;

endmodule