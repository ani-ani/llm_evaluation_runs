module binomial_sum_module (
    input [3:0] n,
    output reg [15:0] result
);

    integer i, j;
    reg [15:0] C [0:16][0:7]; // 2D array for Pascal's triangle, N up to 16, K up to 7

    always @(*) begin
        // Initialize array to prevent latch inference
        for (i = 0; i <= 16; i = i + 1) begin
            for (j = 0; j <= 7; j = j + 1) begin
                C[i][j] = 16'b0;
            end
        end

        // Compute Pascal's triangle iteratively
        // We need coefficients up to N = 2n (max 16) and K = n-1 (max 7)
        for (i = 0; i <= 16; i = i + 1) begin
            for (j = 0; j <= 7; j = j + 1) begin
                if (j == 0) begin
                    C[i][j] = 16'd1;
                end else if (i >= j) begin
                    // C[i][j] = C[i-1][j-1] + C[i-1][j]
                    // Ensure indices are valid (i-1 >= 0 implicitly as i >= j > 0)
                    C[i][j] = C[i-1][j-1] + C[i-1][j];
                end
            end
        end

        // Assign result: C(2n, n-1)
        // Handle boundary case for n=1 (K=0) where result is 1
        if (n >= 1 && n <= 8) begin
            if (n == 1) begin
                result = 16'd1;
            end else begin
                result = C[n << 1][n - 1];
            end
        end else begin
            result = 16'b0; // Default for invalid input range
        end
    end

endmodule
