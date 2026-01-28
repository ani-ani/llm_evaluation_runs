module cone_lsa_calc (
    input  [15:0] r,
    input  [15:0] h,
    output [31:0] area
);

    // Internal signals
    reg  [31:0] r_q16;
    reg  [31:0] h_q16;
    reg  [31:0] r2_q16;
    reg  [31:0] h2_q16;
    reg  [63:0] mult_temp_1;
    reg  [63:0] mult_temp_2;
    reg  [63:0] mult_temp_3;
    reg  [31:0] l_squared_q16;
    reg  [31:0] l_q16;
    reg  [31:0] pi_q16;
    reg  [63:0] area_calc;

    // Local parameters
    localparam [31:0] PI_Q16 = 32'h0003243F; // 3.14159 * 2^16

    // Step 1: Preprocessing - Convert inputs to Q16.16
    // r and h are 16-bit integers. Shifting left by 16 zeros out fractional bits.
    always @(*) begin
        r_q16 = {r, 16'd0};
        h_q16 = {h, 16'd0};
    end

    // Step 2: Calculate r2 and h2 (r^2, h^2)
    // Multiplication: 32-bit * 32-bit -> 64-bit product
    // Since inputs are in Q16.16, product is in Q32.32.
    // We take upper 32 bits [63:32] for Q16.16 result.
    always @(*) begin
        // r^2 calculation
        mult_temp_1 = r_q16 * r_q16;
        r2_q16 = mult_temp_1[63:32];
        
        // h^2 calculation
        mult_temp_2 = h_q16 * h_q16;
        h2_q16 = mult_temp_2[63:32];
    end

    // Step 3: Slant Height (l) Calculation
    // l = sqrt(r^2 + h^2)
    // We perform addition directly on Q16.16 values.
    // For sqrt, we assume a small combinational implementation (e.g., 8-iteration CORDIC or approx)
    // Here we implement a simple iterative approximation logic.
    always @(*) begin
        l_squared_q16 = r2_q16 + h2_q16;
        
        // Approximation for sqrt using 8 iterations of a simple shift-add method
        // Newton-Raphson or similar requires initial guess. 
        // Given range approx 0 to 650 (int part), starting guess is simple.
        // To keep it fully combinational and small:
        // 1. Initial guess = l_squared_q16 >> 1 (very rough)
        // 2. Iterate Newton-Raphson: X_new = 0.5 * (X + N/X)
        // We will unroll 4 iterations for reasonable precision.
        
        // Iteration variables
        reg [31:0] x0, x1, x2, x3, x4;
        reg [63:0] temp_div;
        
        // Initial guess (N >> 1)
        x0 = l_squared_q16 >> 1;
        if (l_squared_q16 == 32'd0) x0 = 32'd0;
        else if (x0 == 32'd0) x0 = 32'd1; // Avoid div by zero
        
        // Iteration 1
        temp_div = l_squared_q16 * x0; // Q32.32
        x1 = (x0 + (temp_div >> 32)) >> 1; // (x + N/x) / 2
        
        // Iteration 2
        temp_div = l_squared_q16 * x1;
        x2 = (x1 + (temp_div >> 32)) >> 1;
        
        // Iteration 3
        temp_div = l_squared_q16 * x2;
        x3 = (x2 + (temp_div >> 32)) >> 1;
        
        // Iteration 4
        temp_div = l_squared_q16 * x3;
        x4 = (x3 + (temp_div >> 32)) >> 1;
        
        l_q16 = x4;
    end

    // Step 4 & 5: Area Calculation
    // area = (r * PI * l) >> 16
    // Formula: A = PI * r * l
    // All inputs are Q16.16. Result needs to be Q16.16.
    // Product of 3 values: (PI * r * l)
    // PI is ~3.14 (Q16.16), r is Q16.16, l is Q16.16.
    // Full precision product is Q48.48.
    // We need result in Q16.16, so we shift right by 32 bits total from the full 64-bit product.
    // Or sequentially: ( (PI * r) >> 16 ) * l -> gives Q16.16 * Q16.16 -> Q32.32 -> take upper 32.
    always @(*) begin
        pi_q16 = PI_Q16;
        
        // First multiplication: PI_Q16 * r_q16
        // 32x32 -> 64. Result is Q32.32.
        // We want to reduce to Q16.16 roughly before multiplying by l.
        // Upper 32 bits of (PI * r) gives the magnitude in Q16.16.
        mult_temp_3 = pi_q16 * r_q16;
        
        // Intermediate result: (PI * r) in Q16.16
        // (mult_temp_3[63:32])
        // Multiply by l (Q16.16)
        // (Q16.16 * Q16.16) = Q32.32
        mult_temp_1 = mult_temp_3[63:32] * l_q16;
        
        // Final result is upper 32 bits of the second product
        // This is equivalent to shifting right by 32 bits of the total product chain.
        area_calc = mult_temp_1;
    end

    // Output assignment
    assign area = area_calc[63:32];

endmodule