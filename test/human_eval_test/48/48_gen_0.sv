module palindrome_checker(
  input  [63:0] text,
  output        is_pal
);

  // Extract character bytes (left-aligned, char0 is MSB, char7 is LSB)
  wire [7:0] c0 = text[63:56];
  wire [7:0] c1 = text[55:48];
  wire [7:0] c2 = text[47:40];
  wire [7:0] c3 = text[39:32];
  wire [7:0] c4 = text[31:24];
  wire [7:0] c5 = text[23:16];
  wire [7:0] c6 = text[15:8];
  wire [7:0] c7 = text[7:0];

  // NUL detection
  wire c0_null = (c0 == 8'h00);
  wire c1_null = (c1 == 8'h00);
  wire c2_null = (c2 == 8'h00);
  wire c3_null = (c3 == 8'h00);
  wire c4_null = (c4 == 8'h00);
  wire c5_null = (c5 == 8'h00);
  wire c6_null = (c6 == 8'h00);
  wire c7_null = (c7 == 8'h00);

  // Effective length: from left until first NUL
  wire [3:0] len = c0_null ? 4'd0 :
                   c1_null ? 4'd1 :
                   c2_null ? 4'd2 :
                   c3_null ? 4'd3 :
                   c4_null ? 4'd4 :
                   c5_null ? 4'd5 :
                   c6_null ? 4'd6 :
                   c7_null ? 4'd7 :
                             4'd8;

  // XOR-based mismatch per pair, enabled only when both indices are within length
  // Pair (0,7)
  wire p0_en = (len > 4'd7);
  wire p0_mismatch = p0_en & |(c0 ^ c7);

  // Pair (1,6)
  wire p1_en = (len > 4'd6);
  wire p1_mismatch = p1_en & |(c1 ^ c6);

  // Pair (2,5)
  wire p2_en = (len > 4'd5);
  wire p2_mismatch = p2_en & |(c2 ^ c5);

  // Pair (3,4)
  wire p3_en = (len > 4'd4);
  wire p3_mismatch = p3_en & |(c3 ^ c4);

  // is_pal high only if no mismatches for all active pairs
  assign is_pal = ~(p0_mismatch | p1_mismatch | p2_mismatch | p3_mismatch);

endmodule