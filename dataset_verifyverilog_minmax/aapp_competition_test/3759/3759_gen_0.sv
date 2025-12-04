module min_blocked_points (
  input reg [15:0] n,
  output reg [19:0] result
);

  // constant sqrt2 approx in Q16.16 format
  localparam [17:0] SQRT2 = 18'd92682; // 0x16A0A

  // 34-bit product of n (16 bits) and sqrt2 constant (18 bits)
  logic [33:0] product;
  assign product = n * SQRT2;

  // Extract integer part after Q16.16 fixed-point division by 2^16
  logic [17:0] integer_part;
  assign integer_part = product[33:16];

  // Compute final result: 4 * integer_part
  logic [19:0] result_pre;
  assign result_pre = integer_part * 4;

  // Special case: when n == 0, output 1
  assign result = (n == 0) ? 20'd1 : result_pre;

endmodule