module poly_derivative (
  input [2:0] num_coeffs,
  input [15:0] xs [0:7],
  output reg [15:0] deriv [0:6],
  output reg [2:0] deriv_len
);

  integer i;
  always @* begin
    deriv_len = 0;
    for (i = 0; i < 7; i = i + 1) begin
      deriv[i] = 0;
    end
    if (num_coeffs > 1) begin
      deriv_len = num_coeffs - 1;
      for (i = 0; i < num_coeffs - 1; i = i + 1) begin
        deriv[i] = xs[i + 1] * (i + 1);
      end
    end
  end

endmodule