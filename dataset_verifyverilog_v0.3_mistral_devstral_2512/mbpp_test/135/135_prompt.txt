module hexagonal_num (
    input wire [7:0] n,
    output reg [15:0] result
);

// Calculate nth hexagonal number: n * (2*n - 1)
// Input n: 8-bit unsigned (0-255)
// Output result: 16-bit unsigned
// Max output: 255 * 509 = 129,795 (fits in 17 bits, 16-bit handles n<=180)

always @(*) begin
    result = n * ((2 * n) - 1);
end

endmodule