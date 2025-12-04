module binomial_sum_product (input [2:0] n, output reg [7:0] result);
  reg [7:0] C [0:4];
  integer i, j, k;

  always @(*) begin
    k = n - 1;  // k is between 0 and 4 for n in 1-5

    // Initialize array: all zeros, then set C[0] to 1
    for (j = 0; j <= 4; j = j+1) begin
      C[j] = 8'h00;
    end
    C[0] = 8'h01;

    // Compute binomial coefficients using iterative method
    // Run from i=1 to 2*n
    for (i = 1; i <= (2*n); i = i+1) begin
      // Determine the upper bound for inner loop: min(i, k)
      if (i < k) 
        j = i;
      else 
        j = k;

      // Inner loop: update from min(i,k) down to 1
      for (j = j; j >= 1; j = j-1) begin
        C[j] = C[j] + C[j-1];
      end
    end

    // Assign result: C[k] if k in valid range, else 0
    if (k >= 0 && k <= 4)
      result = C[k];
    else
      result = 8'h00;
  end
endmodule