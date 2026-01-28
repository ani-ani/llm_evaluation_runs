module opponent_location(
    input wire [9:0] l,        // l value (1-1000)
    output reg [63:0] result_fixed  // Fixed-point result (Q32.32)
);

    // Constants (precomputed as fixed-point Q32.32)
    // 1/(πe) ≈ 0.116577... * 2^32 = 500,714,387
    localparam [63:0] INV_PI_E_FIXED = 64'd500714387;
    
    // Intermediate calculations
    wire [63:0] l_squared;      // l² in Q32.32 (l² * 2^32)
    wire [63:0] term1;          // l²/(πe) in Q32.32
    wire [63:0] denom;          // (l+1) in Q32.32 (just shifted left by 32)
    wire [63:0] term2_numer;    // Numerator for term2
    wire [63:0] term2;          // 1/(l+1) in Q32.32
    
    // Calculate l² (up to 1,000,000, fits in 20 bits)
    // Multiply by 2^32 to convert to Q32.32
    wire [31:0] l_sq_scaled;
    assign l_sq_scaled = l * l;  // l² as integer
    assign l_squared = {l_sq_scaled, 32'd0};  // Shift left by 32 to get Q32.32
    
    // term1 = l²/(πe) in Q32.32
    // Multiply Q32.32 * Q32.32 = Q64.64, take middle 32 bits for result
    wire [95:0] term1_mult;
    assign term1_mult = l_squared * INV_PI_E_FIXED;  // 64*64 = 128 bit result
    // For Q32.32 * Q32.32, result is Q64.64
    // We want middle 32 bits (bits 63:32 of the 128-bit product)
    assign term1 = term1_mult[63:32];
    
    // Calculate 1/(l+1) in Q32.32
    // Input: (l+1) as Q32.32 (i.e., (l+1) << 32)
    // Output: 1/(l+1) in Q32.32 = (2^32) / (l+1) with rounding
    wire [31:0] denom_int;  // l+1 as integer
    assign denom_int = l + 10'd1;
    assign denom = {denom_int, 32'd0};  // (l+1) in Q32.32
    
    // term2 = 1/(l+1) in Q32.32
    // We need (2^64) / (l+1) then shift right by 32
    // More precisely: (2^32) / (l+1) in Q32.32 means (2^32 * 2^32) / (l+1) / 2^32
    // = (2^64 / (l+1)) >> 32
    wire [95:0] term2_numer_full;  // (2^64) / (l+1)
    assign term2_numer_full = (64'd18446744073709551616 / denom_int);
    // Shift right by 32 to get Q32.32 result
    assign term2 = term2_numer_full[63:0];  // Take lower 64 bits
    
    // Sum both terms
    always @(*) begin
        result_fixed = term1 + term2;
    end

endmodule