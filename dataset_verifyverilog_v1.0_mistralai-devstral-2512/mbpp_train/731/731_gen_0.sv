module cone_lsa_calc(
    input [15:0] r,
    input [15:0] h,
    output [31:0] area
);

    // Constants
    localparam [31:0] PI_Q16 = 32'h0003243F;  // 3.14159 in Q16.16

    // Convert inputs to Q16.16 format
    wire [31:0] r_q16 = {16'd0, r};
    wire [31:0] h_q16 = {16'd0, h};

    // Calculate r^2 and h^2
    wire [63:0] r2_temp = $signed(r_q16) * $signed(r_q16);
    wire [63:0] h2_temp = $signed(h_q16) * $signed(h_q16);
    wire [31:0] r2 = r2_temp[63:32];  // Upper 32 bits
    wire [31:0] h2 = h2_temp[63:32];  // Upper 32 bits

    // Calculate l_squared = r^2 + h^2
    wire [31:0] l_squared = r2 + h2;

    // Calculate l = sqrt(l_squared)
    wire [31:0] l = sqrt_fixed(l_squared);

    // Calculate area = PI * r * l
    wire [63:0] pi_r_temp = $signed(PI_Q16) * $signed(r_q16);
    wire [31:0] pi_r = pi_r_temp[63:32];  // Upper 32 bits
    wire [63:0] area_temp = $signed(pi_r) * $signed(l);
    wire [31:0] area_shifted = area_temp[63:32];  // Upper 32 bits

    // Final result (no additional shift needed as we're already in Q16.16)
    assign area = area_shifted;

endmodule