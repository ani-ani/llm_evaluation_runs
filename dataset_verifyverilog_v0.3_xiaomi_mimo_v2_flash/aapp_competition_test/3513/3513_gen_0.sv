module max_factors_power2 (
    input wire [63:0] X,
    output wire [4:0] k
);

// This module computes the maximum number of distinct powers of 2
// whose product equals X, assuming X is a power of 2.
// The result is the largest integer k such that 1+2+...+k <= log2(X).

// Implementation:
// 1. Compute N = floor(log2(X)) (index of most significant 1 bit).
// 2. Find max k such that k*(k+1)/2 <= N.

// Compute N using a priority encoder (find index of highest set bit).
// Since X is 64 bits, we can use a loop.
// For simplicity, we assume X != 0.

reg [5:0] n; // N is between 0 and 63
reg found_bit;
integer i;

always @(*) begin
    n = 6'd0;
    found_bit = 1'b0;
    // Priority encoder: find highest set bit
    for (i = 63; i >= 0; i = i - 1) begin
        if (X[i] && !found_bit) begin
            n = i;
            found_bit = 1'b1;
        end
    end
end

// Compute k by iterating from 1 to 10 (since max k is about 10 for N<=63)
reg [4:0] k_reg;
reg [5:0] sum_val;
reg [4:0] j;

always @(*) begin
    k_reg = 5'd0;
    for (j = 5'd1; j <= 5'd10; j = j + 5'd1) begin
        sum_val = (j * (j + 5'd1)) >> 1; // Divide by 2
        if (sum_val <= n) begin
            k_reg = j;
        end else begin
            // Continue loop without break
        end
    end
end

assign k = k_reg;

endmodule