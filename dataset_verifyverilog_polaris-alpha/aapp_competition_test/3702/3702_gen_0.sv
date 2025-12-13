module fibonacci_sequence_map(
  input  [19:0] n,  // Not used but kept for interface compatibility
  input  [19:0] a,  // Input 'a' (up to 1e6)
  input  [19:0] d,  // Input 'd' (up to 1e6)
  output [63:0] b,  // Output sequence start
  output [63:0] e   // Output sequence difference
);

  // Constants
  localparam [31:0] MULT_CONST    = 32'd368131125;       // 368131125
  localparam [31:0] MOD_CONST     = 32'd1000000000;      // 1_000_000_000
  localparam [43:0] SCALE_CONST   = 44'd12000000000;     // 12_000_000_000

  // Intermediate products (no clock: purely combinational)
  wire [51:0] temp_a = MULT_CONST * a; // up to ~3.6e14
  wire [51:0] temp_d = MULT_CONST * d;

  // Compute modulo 1_000_000_000 using division (synthesizable for constant divisor)
  wire [31:0] mod_a = temp_a % MOD_CONST;
  wire [31:0] mod_d = temp_d % MOD_CONST;

  // Scale and finalize outputs
  wire [75:0] scaled_b = mod_a * SCALE_CONST; // up to ~1.2e19
  wire [75:0] scaled_e = mod_d * SCALE_CONST;

  assign b = scaled_b[63:0] + 64'd1;
  assign e = scaled_e[63:0];

endmodule