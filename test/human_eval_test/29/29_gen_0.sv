module string_filter(
  input  [255:0] strings_flat,
  input  [63:0]  prefix,
  input  [2:0]   prefix_len,
  output [3:0]   match_mask
);

  // Extract 64-bit strings
  wire [63:0] str0 = strings_flat[63:0];
  wire [63:0] str1 = strings_flat[127:64];
  wire [63:0] str2 = strings_flat[191:128];
  wire [63:0] str3 = strings_flat[255:192];

  // Compute number of bits to compare (prefix_len chars * 8 bits)
  wire [5:0] cmp_bits = {prefix_len, 3'b000};

  // Generate masks for variable-length comparison
  // mask[i] = 1 if bit i is within cmp_bits range, else 0
  wire [63:0] mask = (prefix_len == 3'd0) ? 64'd0 : (~64'd0) << (64 - cmp_bits);

  // Masked comparisons; for prefix_len==0, all strings match by definition
  wire match0 = (prefix_len == 3'd0) ? 1'b1 : (((str0 ^ prefix) & mask) == 64'd0);
  wire match1 = (prefix_len == 3'd0) ? 1'b1 : (((str1 ^ prefix) & mask) == 64'd0);
  wire match2 = (prefix_len == 3'd0) ? 1'b1 : (((str2 ^ prefix) & mask) == 64'd0);
  wire match3 = (prefix_len == 3'd0) ? 1'b1 : (((str3 ^ prefix) & mask) == 64'd0);

  assign match_mask = {match3, match2, match1, match0};

endmodule