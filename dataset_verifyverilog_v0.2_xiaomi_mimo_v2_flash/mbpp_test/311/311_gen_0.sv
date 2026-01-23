module set_left_most_unset_bit(
    input [15:0] n,
    output [15:0] result
);

    // If all bits are set, return n unchanged
    // Otherwise, find the highest bit position that is 0 and set it
    // The logic: for each bit i, if bit i is 0 and all higher bits (15:i+1) are 1, then set bit i
    // This can be computed by: if n != 16'hFFFF, result = n | ~n
    // Actually, n | ~n sets all bits to 1. We need only the highest zero.
    // The highest zero bit in n is the highest set bit in ~n (since ~n has 1 where n has 0).
    // Then result = n | (1 << highest_zero_index)
    // But ~n is 16 bits, we need to find the highest set bit in ~n.
    // This can be done by priority encoder on ~n, from MSB to LSB.
    // Let zero_pattern = ~n;
    // The highest set bit in zero_pattern is the leftmost zero in n.
    // We can use a chain of conditions:
    wire [15:0] zero_pattern = ~n;
    wire [15:0] mask;
    
    // mask[i] = 1 if zero_pattern[i] is 1 and all higher bits zero_pattern[15:i+1] are 0
    // But we want the highest set bit, so mask should have 1 only at that position.
    // Compute using a prefix condition:
    // Let higher_zeros[j] = 1 if zero_pattern[15:j+1] == 0
    // Then mask[i] = zero_pattern[i] & higher_zeros[i]
    // Then result = n | mask
    
    // Compute higher_zeros as a prefix of all zeros above.
    // higher_zeros[i] means all bits above i are zero in zero_pattern.
    // We can compute:
    wire higher_zeros_15 = 1'b1; // No bits above 15
    wire higher_zeros_14 = higher_zeros_15 & (zero_pattern[15] == 0);
    wire higher_zeros_13 = higher_zeros_14 & (zero_pattern[14] == 0);
    wire higher_zeros_12 = higher_zeros_13 & (zero_pattern[13] == 0);
    wire higher_zeros_11 = higher_zeros_12 & (zero_pattern[12] == 0);
    wire higher_zeros_10 = higher_zeros_11 & (zero_pattern[11] == 0);
    wire higher_zeros_9  = higher_zeros_10 & (zero_pattern[10] == 0);
    wire higher_zeros_8  = higher_zeros_9  & (zero_pattern[9] == 0);
    wire higher_zeros_7  = higher_zeros_8  & (zero_pattern[8] == 0);
    wire higher_zeros_6  = higher_zeros_7  & (zero_pattern[7] == 0);
    wire higher_zeros_5  = higher_zeros_6  & (zero_pattern[6] == 0);
    wire higher_zeros_4  = higher_zeros_5  & (zero_pattern[5] == 0);
    wire higher_zeros_3  = higher_zeros_4  & (zero_pattern[4] == 0);
    wire higher_zeros_2  = higher_zeros_3  & (zero_pattern[3] == 0);
    wire higher_zeros_1  = higher_zeros_2  & (zero_pattern[2] == 0);
    wire higher_zeros_0  = higher_zeros_1  & (zero_pattern[1] == 0);
    
    // mask bit i is set if zero_pattern[i] is 1 and higher_zeros_i is 1
    wire [15:0] mask_i;
    assign mask_i[15] = zero_pattern[15] & higher_zeros_15;
    assign mask_i[14] = zero_pattern[14] & higher_zeros_14;
    assign mask_i[13] = zero_pattern[13] & higher_zeros_13;
    assign mask_i[12] = zero_pattern[12] & higher_zeros_12;
    assign mask_i[11] = zero_pattern[11] & higher_zeros_11;
    assign mask_i[10] = zero_pattern[10] & higher_zeros_10;
    assign mask_i[9]  = zero_pattern[9]  & higher_zeros_9;
    assign mask_i[8]  = zero_pattern[8]  & higher_zeros_8;
    assign mask_i[7]  = zero_pattern[7]  & higher_zeros_7;
    assign mask_i[6]  = zero_pattern[6]  & higher_zeros_6;
    assign mask_i[5]  = zero_pattern[5]  & higher_zeros_5;
    assign mask_i[4]  = zero_pattern[4]  & higher_zeros_4;
    assign mask_i[3]  = zero_pattern[3]  & higher_zeros_3;
    assign mask_i[2]  = zero_pattern[2]  & higher_zeros_2;
    assign mask_i[1]  = zero_pattern[1]  & higher_zeros_1;
    assign mask_i[0]  = zero_pattern[0]  & higher_zeros_0;
    
    // Since there is at most one such bit (leftmost zero), we can OR them all, but better to use priority.
    // Actually, mask_i should have only one bit set, so we can OR, but it's safe to use a reduction.
    // However, we need the 16-bit mask for the result. The mask_i is 16 bits with possibly multiple set due to logic error? No, because higher_zeros ensures that only the leftmost zero passes.
    // But we can use a priority encoder style to generate mask directly.
    // Instead, let's generate mask as OR of all mask_i, but that would be correct because only one is set.
    // But mask_i is 16 bits, we need a 16-bit value where only one bit is set. We can OR all mask_i, but each mask_i is a single bit position.
    // Actually, each mask_i is a 16-bit wire with only bit i possibly set. So result_mask = |mask_i? No.
    // We need result_mask such that result_mask[k] = 1 only for the leftmost k.
    // So result_mask = {16{1'b0}}; for each i, result_mask[i] = mask_i[i];
    // But mask_i[i] is already bit i. So we can just use mask_i as the mask.
    // However, mask_i[15] is bit 15, etc. So the mask is exactly mask_i.
    
    // But if n == 16'hFFFF, zero_pattern == 0, all mask_i bits are 0, so result = n, which is correct.
    
    // Therefore:
    assign result = n | mask_i;

endmodule
