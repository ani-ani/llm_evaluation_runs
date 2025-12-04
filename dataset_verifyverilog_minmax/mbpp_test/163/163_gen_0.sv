module poly_area (
  input [3:0] sides,  // 4-bit, values 0-15 (0..15). Valid range: 3..16
  input [4:0] length, // 5-bit, 1..31
  output reg [31:0] area // Q16.16 fixed-point result
);
  // Q16.16 coefficients: coef = sides / (4 * tan(pi/sides))
  // Values precomputed and stored in ROM (case-based)
  localparam [31:0] COEF_3  = 32'h00006ed9; // 0.4329 (triangle)
  localparam [31:0] COEF_4  = 32'h00010000; // 1.0000 (square)
  localparam [31:0] COEF_5  = 32'h00015b48; // 1.3764 (pentagon)
  localparam [31:0] COEF_6  = 32'h0001c28f; // 1.63299 (hexagon)
  localparam [31:0] COEF_7  = 32'h000231f3; // 2.19911 (heptagon)
  localparam [31:0] COEF_8  = 32'h00029436; // 2.82843 (octagon)
  localparam [31:0] COEF_9  = 32'h0002ed6e; // 3.53300 (nonagon)
  localparam [31:0] COEF_10 = 32'h00033e20; // 4.00000 (decagon)
  localparam [31:0] COEF_11 = 32'h0003892f; // 4.59164 (hendecagon)
  localparam [31:0] COEF_12 = 32'h0003cc16; // 5.19615 (dodecagon)
  localparam [31:0] COEF_13 = 32'h000408b0; // 5.88084 (tridecagon)
  localparam [31:0] COEF_14 = 32'h00043f1d; // 6.59700 (tetradecagon)
  localparam [31:0] COEF_15 = 32'h000470d1; // 7.34685 (pentadecagon)
  localparam [31:0] COEF_16 = 32'h0003c3f2; // 3.06186 (hexadecagon) [corrected]

  function [31:0] q16_16_mul (input [31:0] a, input [31:0] b);
    // (Q16.16 * Q16.16) -> Q16.16, keep high 32 bits of the 64-bit product
    q16_16_mul = $unsigned($signed(a) * $signed(b)) >> 16;
  endfunction

  always_comb begin
    if ((sides >= 4'd3) && (sides <= 4'd16)) begin
      // length_squared in Q16.16: (length << 16)
      length_sq = {length, 16'b0};
      case (sides)
        4'd3:  area = q16_16_mul(COEF_3,  length_sq);
        4'd4:  area = q16_16_mul(COEF_4,  length_sq);
        4'd5:  area = q16_16_mul(COEF_5,  length_sq);
        4'd6:  area = q16_16_mul(COEF_6,  length_sq);
        4'd7:  area = q16_16_mul(COEF_7,  length_sq);
        4'd8:  area = q16_16_mul(COEF_8,  length_sq);
        4'd9:  area = q16_16_mul(COEF_9,  length_sq);
        4'd10: area = q16_16_mul(COEF_10, length_sq);
        4'd11: area = q16_16_mul(COEF_11, length_sq);
        4'd12: area = q16_16_mul(COEF_12, length_sq);
        4'd13: area = q16_16_mul(COEF_13, length_sq);
        4'd14: area = q16_16_mul(COEF_14, length_sq);
        4'd15: area = q16_16_mul(COEF_15, length_sq);
        4'd16: area = q16_16_mul(COEF_16, length_sq);
        default: area = 32'h0; // Should not occur due to if-check
      endcase
    end else begin
      // Invalid sides (0,1,2) or values >=17 output 0
      area = 32'h0;
    end
  end
endmodule
