module SetEvenBits (
    input [15:0] n,
    output reg [15:0] result
);

    // 0x5555 in binary: 0101 0101 0101 0101
    // This mask has 1s at all even positions (0,2,4,...,14)
    localparam [15:0] EVEN_MASK = 16'h5555;

    always @(*) begin
        // Set all even-positioned bits to 1, preserve odd bits
        result = n | EVEN_MASK;
    end

endmodule