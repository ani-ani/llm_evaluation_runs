module cone_volume(
  input  [7:0]  r,
  input  [7:0]  h,
  output [31:0] volume
);

  // Constants in Q16.16
  localparam [31:0] PI         = 32'h0003243F; // π
  localparam [31:0] ONE_THIRD  = 32'h00005555; // 1/3

  // Step 1: r_squared = r * r (16-bit)
  wire [15:0] r_squared;
  assign r_squared = r * r;

  // Step 2: π_times_r² = Q16.16_mult(π, {16'b0, r_squared})
  // Q16.16_mult(a,b): (a * b) >> 16
  wire [31:0] r2_q16;
  assign r2_q16 = {16'b0, r_squared};

  wire [63:0] mul_pi_r2_full;
  wire [31:0] pi_times_r2;
  assign mul_pi_r2_full = PI * r2_q16;
  assign pi_times_r2    = mul_pi_r2_full[47:16];

  // Step 3: intermediate = Q16.16_mult(π_times_r², {24'b0, h})
  wire [31:0] h_q16;
  assign h_q16 = {24'b0, h};

  wire [63:0] mul_pi_r2_h_full;
  wire [31:0] intermediate;
  assign mul_pi_r2_h_full = pi_times_r2 * h_q16;
  assign intermediate      = mul_pi_r2_h_full[47:16];

  // Step 4: volume = Q16.16_mult(intermediate, ONE_THIRD)
  wire [63:0] mul_final_full;
  assign mul_final_full = intermediate * ONE_THIRD;
  assign volume         = mul_final_full[47:16];

endmodule