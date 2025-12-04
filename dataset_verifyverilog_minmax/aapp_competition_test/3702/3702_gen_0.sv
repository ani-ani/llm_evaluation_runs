module fibonacci_sequence_map(
  input [19:0] n,  // Not used but kept for interface compatibility
  input [19:0] a,  // Input 'a' (up to 1e6)
  input [19:0] d,  // Input 'd' (up to 1e6)
  output reg [63:0] b, // Output sequence start
  output reg [63:0] e  // Output sequence difference
);

  // Extended operands to 40 bits to avoid overflow before mod; all results fit in 64 bits
  wire [39:0] a_ext = {20'b0, a};
  wire [39:0] d_ext = {20'b0, d};

  wire [39:0] temp_a = 368131125 * a_ext;        // 40-bit product to prevent overflow
  wire [39:0] temp_d = 368131125 * d_ext;

  wire [29:0] mod_a = temp_a % 1000000000;       // 30 bits suffice (mod 1e9)
  wire [29:0] mod_d = temp_d % 1000000000;

  wire [63:0] scale = 64'd12000000000;           // 12e9, fits in 36 bits, used as 64-bit

  always_comb begin
    b = (mod_a * scale) + 64'd1;
    e = (mod_d * scale);
  end

endmodule