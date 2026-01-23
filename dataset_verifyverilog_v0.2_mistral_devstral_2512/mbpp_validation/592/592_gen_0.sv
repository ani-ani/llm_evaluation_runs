module binomial_sum_module(
  input [3:0] n,
  output [15:0] result
);

  // Intermediate array to store binomial coefficients
  reg [15:0] C [0:16][0:8];
  integer i, j;

  // Combinational logic to compute binomial coefficient
  always @* begin
    // Initialize all values to 0
    for (i = 0; i <= 16; i = i + 1) begin
      for (j = 0; j <= 8; j = j + 1) begin
        C[i][j] = 0;
      end
    end

    // Compute binomial coefficients using Pascal's triangle
    for (i = 0; i <= 2*n; i = i + 1) begin
      for (j = 0; j <= (i < n ? i : n-1); j = j + 1) begin
        if (j == 0) begin
          C[i][j] = 1;
        end else begin
          C[i][j] = C[i-1][j-1] + C[i-1][j];
        end
      end
    end

    // Assign the result
    result = C[2*n][n-1];
  end

endmodule