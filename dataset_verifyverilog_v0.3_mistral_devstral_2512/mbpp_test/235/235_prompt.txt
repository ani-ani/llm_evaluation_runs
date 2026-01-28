module even_bit_set(
    input [15:0] n,
    output [15:0] result
);

// Set all even bits (bit positions 0, 2, 4, 6, 8, 10, 12, 14)
// Note: bit positions are 0-indexed from LSB
// Even positions: 0, 2, 4, 6, 8, 10, 12, 14
// Mask: 0101 0101 0101 0101 = 0x5555

assign result = n | 16'h5555;

endmodule