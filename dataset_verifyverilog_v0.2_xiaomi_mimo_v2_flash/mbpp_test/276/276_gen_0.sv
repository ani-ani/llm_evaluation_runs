module cylinder_volume (
    input  [15:0] radius,
    input  [15:0] height,
    output [31:0] volume
);

    // Fixed-point constant for PI in Q16.16 format (0x3243F)
    // 3.141592653589793 * 65536 = 205887.468
    // Integer value 205887 = 0x0003243F
    wire [31:0] PI_FIXED = 32'h0003243F;

    // Intermediate signals
    // Scale inputs to Q16.16 format by shifting left 16 bits
    wire [31:0] r_fixed = {radius, 16'h0000};
    wire [31:0] h_fixed = {height, 16'h0000};

    // Compute r^2: (r_fixed * r_fixed)
    // Result is 64 bits. Since inputs are 32 bits (16.16), product is 64 bits (32.32)
    wire [63:0] r_squared_full = r_fixed * r_fixed;

    // Compute r^2 * PI
    // r_squared_full is 64 bits (32.32). PI_FIXED is 32 bits (16.16).
    // Product is 96 bits (48.48). We only need to preserve enough bits for the final result.
    wire [95:0] r_sq_pi_full = r_squared_full * PI_FIXED;

    // Compute (r^2 * PI) * h
    // r_sq_pi_full is 96 bits. h_fixed is 32 bits (16.16).
    // Product is 128 bits (64.64).
    wire [127:0] volume_full = r_sq_pi_full * h_fixed;

    // Final Normalization:
    // We need the result in Q16.16 format (32 bits).
    // The source calculation involves:
    // r (16.0) -> r_fixed (16.16)
    // r^2 (32.32) -> r^2 * PI (48.48) -> * h (64.64)
    // To convert 64.64 to 16.16, we need to discard 48 fractional bits and keep 16 integer bits.
    // The instruction asks for bits [47:16] of the final 64-bit product (assuming 32x32 multipliers).
    // Given the chain of operations, the physical bits [47:16] of the final 128-bit result 
    // correspond to the correct mantissa if we consider the effective shift.
    // volume_full[127:0] is 64.64 fixed point.
    // Integer part is [127:64], Fractional part is [63:0].
    // To get 16.16, we take [79:48] from the total 128 bits (Top 16 bits of integer, bottom 16 bits of fraction).
    // However, sticking strictly to the prompt's bit extraction guidance on the 64-bit intermediate product
    // implies taking the mid-bits. If we perform 3 32x32 multiplies sequentially, the bit alignment varies.
    // Since we implemented a single expression chain, we select [79:48].
    // Alternatively, if we strictly interpret "64-bit product" as the result of r^2 * PI * h 
    // assuming r^2 and h were 32-bit products:
    // (r << 16) * (r << 16) -> 64b (32.32)
    // (32.32) * (h << 16) -> 96b (48.48) -> Slice [47:16] is unavailable for 48.48.
    // 
    // Re-evaluating instruction: "Take the middle 32 bits of the final 64-bit product (bits [47:16])".
    // This assumes the result fits in 64 bits. For (r^2 * PI * h), it does not fit in 64 bits for max inputs.
    // However, if we follow the multiplication order strictly:
    // 1. r_fixed * r_fixed = 64b (32.32). Let's call this Mid1.
    // 2. Mid1 * PI = 96b (48.48).
    // 3. (Mid1 * PI) * h_fixed = 128b (64.64).
    // 
    // Let's try to fit the "64-bit product" description. Perhaps it refers to the immediate 64-bit result 
    // of the multiplication `r_sq_pi * h`. If `r_sq_pi` is treated as a 32-bit value, and `h` as 32-bit.
    // But `r_sq_pi` is 48.48. 
    // 
    // Let's provide the mathematically correct solution for Q16.16 output using the full width,
    // but extracting bits that match the prompt's intent (middle 32 bits of the data width).
    // The data is 64.64. The Q16.16 result is effectively bits [79:48].
    // 
    // Correction: Prompt says "Assume 32x32 multipliers". 
    // r_fixed (32) * r_fixed (32) -> 64b.
    // (Result64) * PI (32) -> 96b.
    // (Result96) * h_fixed (32) -> 128b.
    // To keep it simple and aligned with the likely intent of a homework/demonstration problem:
    // The prompt asks for bits [47:16]. 
    // If we look at the first multiplication (r^2): 64b result. [47:16] is useful.
    // But we have to multiply by h. 
    // 
    // Let's stick to the exact calculation 0x3243F * r^2 * h.
    // We will output bits [79:48] of the final 128-bit calculation.
    // This effectively implements the scaling correctly.

    assign volume = volume_full[79:48];

endmodule
