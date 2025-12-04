module min_blocked_points(
  input  [15:0] n,      // Input n (0 ≤ n ≤ 65535)
  output [19:0] result  // Minimum blocked points count
);

  // Local parameter for sqrt(2) in Q16.16: 0x00016A0A (18-bit value 0..17)
  localparam [17:0] SQRT2_Q16_16 = 18'h16A0A; // 92682 decimal

  // 16-bit * 18-bit -> 34-bit product
  wire [33:0] prod = n * SQRT2_Q16_16;

  // Shift-right by 16 to obtain Q16.0 integer-like value (still up to 18 bits needed)
  wire [17:0] scaled = prod[33:16];

  // Multiply by 4 (left shift by 2), fit into 20 bits
  wire [19:0] calc = {scaled, 2'b00};

  // Special case for n == 0
  assign result = (n == 16'd0) ? 20'd1 : calc;

endmodule