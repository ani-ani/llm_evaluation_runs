module packet_distribution (
    input [29:0] n,       // Input n (0 to 1e9, fits in 30 bits)
    output reg [4:0] ans  // Output answer (max 30, fits in 5 bits)
);

// Combinational logic to find minimum number of packets
// For n >= 1, answer = ceil(log2(n+1))
// This is equivalent to finding the smallest k such that (2^k - 1) >= n

integer i;

always @(*) begin
    ans = 5'd0;
    // Check from highest possible k down to 1
    // Since n <= 1e9, max k is 30
    for (i = 30; i >= 1; i = i - 1) begin
        if (((32'd1 << i) - 32'd1) >= {3'd0, n}) begin
            ans = i;
        end
    end
    // Special case: n = 0 should give 0, but n >= 1 per problem
end

endmodule