module even_position(
    input [7:0] nums,
    output result
);

    // Since nums is 8 bits for an 8-element array, we interpret it as packed.
    // Assuming nums[0] is bit 0 (LSB) for element 0, nums[7] is bit 7 (MSB) for element 7.
    // We verify parity at each index.

    // Index 0 (even): nums[0] == 0
    // Index 1 (odd): nums[1] == 1
    // Index 2 (even): nums[2] == 0
    // Index 3 (odd): nums[3] == 1
    // Index 4 (even): nums[4] == 0
    // Index 5 (odd): nums[5] == 1
    // Index 6 (even): nums[6] == 0
    // Index 7 (odd): nums[7] == 1

    // If any check fails (XOR 1), result is 0.
    // Result is 1 only if all checks pass.

    assign result = ~(nums[0] ^ 1'b0) &
                    ~(nums[1] ^ 1'b1) &
                    ~(nums[2] ^ 1'b0) &
                    ~(nums[3] ^ 1'b1) &
                    ~(nums[4] ^ 1'b0) &
                    ~(nums[5] ^ 1'b1) &
                    ~(nums[6] ^ 1'b0) &
                    ~(nums[7] ^ 1'b1);

endmodule
