module bit_rotate_left (
    input [31:0] data_in,
    input [4:0] rotate_bits,
    output [31:0] result
);

    // Implement circular left shift: (data_in << rotate_bits) | (data_in >> (32 - rotate_bits))
    // Note: rotate_bits is 5 bits (0-31), so (32 - rotate_bits) is computed as (32 - rotate_bits)
    // When rotate_bits is 0, right shift is 32, which shifts all bits out (result is 0), but OR with left shift (no shift) gives correct result.
    // However, verilog shift with 32 will shift all bits out, but we need to handle 32 properly.
    // Actually, for rotate left, when rotate_bits is 0, we want data_in.
    // (data_in << 0) = data_in, (data_in >> 32) = 0, OR = data_in. Correct.
    // When rotate_bits = 32, input is limited to 0-31 by 5 bits, so max 31.
    
    assign result = (data_in << rotate_bits) | (data_in >> (32 - rotate_bits));

endmodule