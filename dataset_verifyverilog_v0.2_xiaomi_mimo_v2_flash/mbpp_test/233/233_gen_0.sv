module lateral_surface_cylinder (
    input [7:0] r,
    input [7:0] h,
    output [31:0] area
);

    // Constant π in Q16.16 format
    localparam PI_Q16 = 205887;

    // Intermediate registers for pipelined multiplication
    // These represent the internal state of the combinational logic
    reg [15:0] mul_r_h;       // r * h
    reg [16:0] mul_2_r_h;     // r * h * 2
    reg [34:0] mul_pi_2_r_h;  // r * h * 2 * π

    // Step 1: Multiply r and h (max 255*255 = 65025, fits in 16 bits)
    always @(*) begin
        mul_r_h = r * h;
    end

    // Step 2: Multiply by 2 (max 65025*2 = 130050, fits in 17 bits)
    always @(*) begin
        mul_2_r_h = {1'b0, mul_r_h} * 2;
    end

    // Step 3: Multiply by π (max 130050 * 205887 ≈ 26.8 billion, fits in 35 bits)
    always @(*) begin
        mul_pi_2_r_h = mul_2_r_h * PI_Q16;
    end

    // Step 4: Right shift by 16 to convert to Q16.16 format
    // Extract bits [31:16] from the 35-bit intermediate result
    // Since the max result is approx 26.8 billion, it fits within the upper 32 bits of the 35-bit register
    // 26.8 billion approx 0x650 943 400 (approx 35 bits), upper bits are valid
    assign area = mul_pi_2_r_h[31:16];

endmodule