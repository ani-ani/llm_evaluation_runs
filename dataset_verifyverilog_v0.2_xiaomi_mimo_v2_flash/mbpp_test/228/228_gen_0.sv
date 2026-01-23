module all_bits_unset_in_range (
    input [31:0] n,
    input [4:0] l,
    input [4:0] r,
    output all_unset
);

    // Intermediate signals for mask generation
    wire [31:0] left_mask;
    wire [31:0] right_mask;
    wire [31:0] range_mask;

    // 1. Create left_mask = (1 << (l-1)) - 1
    // This sets bits 0 to l-2 (inclusive)
    // If l is 0 (invalid per spec but handled), shift by 31 wraps to 0 in hardware, result 0.
    assign left_mask = (1 << (l - 1)) - 1;

    // 2. Create right_mask = (1 << r) - 1
    // This sets bits 0 to r-1 (inclusive)
    assign right_mask = (1 << r) - 1;

    // 3. Create range_mask
    // right_mask has bits [r-1:0] set.
    // left_mask has bits [l-2:0] set.
    // XOR operation leaves bits [r-1:l-1] set, which corresponds to the range [l:r].
    assign range_mask = right_mask ^ left_mask;

    // 4. Result
    // Check if n & range_mask is zero.
    // If 0, all bits in range are unset (output 1).
    // Else, at least one bit is set (output 0).
    assign all_unset = ((n & range_mask) == 0);

endmodule