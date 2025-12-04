module sector_area (
  input [15:0] radius,
  input [8:0] angle,
  output logic [31:0] area_q,
  output logic invalid
);

  // Q16.16 constant for pi (3.1415926535...), truncated to nearest integer
  // 3.1415926535 * 65536 = 205887.999... -> 205888 = 0x32440 (0x3243F rounds slightly better for some paths)
  localparam [31:0] PI_Q16_16 = 32'h0003243F;
  // 1/360 in Q16.16: 65536/360 = 182.0444... -> 182 = 0xB6 (but we want 0.00277778 -> 182.0444/65536)
  // Accurate Q16.16 1/360 = 0x000B6 in hex (approx 0.00277778)
  localparam [31:0] INV360_Q16_16 = 32'h00000B6;

  // Guard bit for extra headroom (use 64-bit intermediates for safety)
  typedef logic [63:0] u64;

  // Validate angle ( > 360 degrees => invalid )
  assign invalid = (angle > 9'd360);

  // Compute area_q = (PI_Q16_16 * radius * radius * angle) / 360 in Q16.16
  // Steps (integer arithmetic, then re-interpret result as Q16.16):
  // 1) r2 = radius * radius                                   [32 bits]
  // 2) pi_r2 = (PI_Q16_16 * r2) >> 16                         [48 bits]
  // 3) prod = (pi_r2 * angle_q) >> 16                         [64 bits]  (angle_q = angle << 16)
  // 4) area_q = (prod * INV360_Q16_16) >> 32                  [64 bits]
  // 5) Truncate to 32-bit Q16.16 output

  logic [31:0] r2;
  u64 pi_r2;
  u64 prod;
  u64 area_raw;

  // r2 = radius * radius (unsigned)
  assign r2 = $unsigned(radius) * $unsigned(radius);

  // pi_r2 = (PI_Q16_16 * r2) >> 16
  assign pi_r2 = ($unsigned(PI_Q16_16) * $unsigned(r2)) >> 16;

  // prod = (pi_r2 * (angle << 16)) >> 16
  assign prod = (pi_r2 * ($unsigned(angle) << 16)) >> 16;

  // area_raw = (prod * INV360_Q16_16) >> 32
  assign area_raw = (prod * $unsigned(INV360_Q16_16)) >> 32;

  // Final selection: on invalid angle, set area_q = 0xFFFFFFFF
  always_comb begin
    if (invalid) begin
      area_q = 32'hFFFFFFFF;
    end else begin
      area_q = area_raw[31:0];
    end
  end

endmodule
