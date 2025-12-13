module sector_area(
    input  [15:0] radius,
    input  [8:0]  angle,
    output [31:0] area_q,
    output        invalid
);

    // Parameters
    localparam [31:0] PI_Q16_16        = 32'h0003243F; // ~3.141592 in Q16.16
    localparam [31:0] INV360_Q16_16    = 32'h000000B7; // ~1/360 in Q16.16 (0.00277778*65536 ≈ 183 = 0x00B7)

    // Internal signals
    wire        angle_invalid;
    wire [31:0] radius_sq;           // up to 32 bits (16x16)
    wire [63:0] pi_mul_radius_sq;    // 32x32 -> 64 bits
    wire [47:0] pi_radius_sq_q16;    // after >>16
    wire [63:0] mul_angle;           // 48x9 <= use 64 bits
    wire [63:0] mul_inv360;          // 64x16 (we use 32-bit INV360) -> 64 bits

    // Invalid angle detection
    assign angle_invalid = (angle > 9'd360);
    assign invalid       = angle_invalid;

    // radius^2 (unsigned)
    assign radius_sq = radius * radius;

    // pi * radius^2 (Q16.16 * integer^2), keep high precision
    assign pi_mul_radius_sq = PI_Q16_16 * radius_sq; // 32x32 -> 64

    // Shift right by 16 to maintain Q16.16 for (pi * r^2)
    assign pi_radius_sq_q16 = pi_mul_radius_sq[63:16]; // 48 bits kept

    // Multiply by angle (still combinational)
    assign mul_angle = pi_radius_sq_q16 * angle; // 48x9 -> <=57 bits, stored in 64

    // Multiply by 1/360 approximation in Q16.16
    assign mul_inv360 = mul_angle * INV360_Q16_16; // result in Q(16.16)

    // Final area_q is already scaled to Q16.16;
    // normalization: (pi*r^2 >>16) * angle * (1/360_Q16.16) >>16
    // Combined: take bits [63:32] as Q16.16 output
    wire [31:0] area_q_calc = mul_inv360[63:32];

    // Apply invalid behavior
    assign area_q = angle_invalid ? 32'hFFFFFFFF : area_q_calc;

endmodule