module sphere_surface_area (
    input [31:0] radius,
    output [31:0] surface_area
);

    // PI constant in Q16.16 format: 3.14159265359 * 2^16 = 205887
    parameter PI_Q16_16 = 205887;

    // Stage 1: Square the radius (r * r)
    // Q16.16 * Q16.16 = Q32.32
    wire [63:0] r_squared_full = radius * radius;
    // Keep upper 32 bits (integer and fractional parts) to get Q16.16
    wire [31:0] r_squared = r_squared_full[47:16];

    // Stage 2: Multiply by PI (PI * r_squared)
    // Q16.16 * Q16.16 = Q32.32
    wire [63:0] pi_times_r_squared_full = r_squared * PI_Q16_16;
    // Keep upper 32 bits to get Q16.16
    wire [31:0] pi_times_r_squared = pi_times_r_squared_full[47:16];

    // Stage 3: Multiply by 4
    // Q16.16 * 4 = Q16.16
    assign surface_area = pi_times_r_squared << 2;

endmodule