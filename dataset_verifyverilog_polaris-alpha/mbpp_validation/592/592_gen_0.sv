module binomial_sum_product(
  input  [2:0] n,
  output [7:0] result
);

  // Compute result = C(2*n, n-1) using the specified iterative method.
  // Purely combinational implementation using a combinational for-loop.

  integer i, j;
  integer nn, kk; // nn = 2*n, kk = n-1
  reg [7:0] C[0:7]; // Sufficiently large for max k <= 4

  always @* begin
    // Handle n=1 special case (C(2,0)=1) and out-of-range defensively
    if (n < 1 || n > 5) begin
      // Outside valid range; define as 0
      for (i = 0; i < 8; i = i + 1) C[i] = 8'd0;
    end else if (n == 1) begin
      // Directly set for n = 1
      for (i = 0; i < 8; i = i + 1) C[i] = 8'd0;
      C[0] = 8'd1; // C(2,0) = 1
    end else begin
      // General case using iterative method for C(2*n, k) with k = n-1
      nn = 2 * n;
      kk = n - 1;
      // Initialize coefficients array
      for (i = 0; i <= kk; i = i + 1) begin
        C[i] = 8'd0;
      end
      C[0] = 8'd1;

      // Pascal-based DP: build row-by-row up to nn
      for (i = 1; i <= nn; i = i + 1) begin
        // j runs downwards to avoid overwriting data needed for this row
        for (j = (i < kk ? i : kk); j >= 1; j = j - 1) begin
          C[j] = C[j] + C[j-1];
        end
      end
    end
  end

  assign result = C[(n >= 1 && n <= 5) ? (n - 1) : 0];

endmodule