module sum_to_n(
    input [15:0] n,
    output reg [31:0] result
);
    always @(*) begin
        // Compute sum = n * (n + 1) / 2
        // n is 16-bit, n+1 is also 16-bit (max 500+1 = 501)
        // n*(n+1) needs 32-bit result (max 500*501 = 250500 fits in 18 bits)
        // Result max 250500/2 = 125250 fits in 17 bits, so 32-bit is safe
        result = n * (n + 16'd1) / 16'd2;
    end
endmodule