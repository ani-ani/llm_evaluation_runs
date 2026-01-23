module divisibility_hack(
    input [63:0] b,
    input [63:0] d,
    output valid
);

    // If d is 0, avoid division by zero. Treat as invalid.
    // The function is undefined for d=0, but valid must be 0.
    wire is_d_zero = (d == 64'd0);

    // 1. remainder = b % d
    // If d=0, remainder is undefined; we force 0 to avoid x propagation,
    // but the final valid will be 0 anyway.
    wire [63:0] remainder = is_d_zero ? 64'd0 : (b % d);

    // 2. Check if remainder == 0
    wire rem_is_zero = (remainder == 64'd0);

    // 3. Compute exponent = (d - 1) >> 1
    wire [63:0] exponent = (d - 64'd1) >> 1;

    // 4. Compute modular_pow(remainder, exponent, d)
    // Internal signals for modular exponentiation state
    reg  [63:0] pow_base;
    reg  [63:0] pow_exp;
    reg  [63:0] pow_res;
    
    // Combinational logic for modular exponentiation
    // Using a loop for the exponentiation process since it's combinational
    integer i;
    
    always @(*) begin
        if (is_d_zero || rem_is_zero) begin
            // If inputs are invalid or remainder is 0, we don't need to compute power.
            // Result defaults to 0 (or anything != 1).
            pow_res = 64'd0;
        end else begin
            // Standard modular exponentiation algorithm
            // Initialize: base = remainder % d, result = 1
            // Since remainder < d (from modulo op), remainder % d is just remainder.
            pow_base = remainder;
            pow_res = 64'd1;
            pow_exp = exponent;
            
            // Loop handles the exponentiation
            // We use 64 iterations to cover full 64-bit exponent range
            for (i = 0; i < 64; i = i + 1) begin
                if (pow_exp != 64'd0) begin
                    // If LSB is 1, multiply result by base modulo d
                    if (pow_exp[0]) begin
                        // Multiply: (pow_res * pow_base) % d
                        // Use 128-bit intermediate to prevent overflow
                        // Since d <= 64 bits, the product of two 64-bit numbers is 128 bits.
                        // (a * b) % d = ((a % d) * (b % d)) % d.
                        // Here pow_res and pow_base are already < d.
                        pow_res = (({64'd0, pow_res} * {64'd0, pow_base}) % d);
                    end
                    
                    // Square base: (base * base) % d
                    pow_base = (({64'd0, pow_base} * {64'd0, pow_base}) % d);
                    
                    // Shift exponent
                    pow_exp = pow_exp >> 1;
                end
            end
        end
    end

    // 5. If result == 1, valid = 1, else valid = 0
    wire result_is_one = (pow_res == 64'd1);
    
    // Valid if: d != 0, remainder != 0, AND modular_pow result == 1
    assign valid = (!is_d_zero && !rem_is_zero && result_is_one);

endmodule
