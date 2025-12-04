module min_swaps(
  input  [3:0] str1,
  input  [3:0] str2,
  output [2:0] swap_count,
  output       error
);

  // Compute mismatch bits
  wire [3:0] mismatches = str1 ^ str2;

  // Population count of mismatches (0..4)
  wire [2:0] ones01 = mismatches[0] + mismatches[1];
  wire [2:0] ones23 = mismatches[2] + mismatches[3];
  wire [2:0] mismatch_count = ones01 + ones23;

  // Error when mismatch_count is odd
  assign error = mismatch_count[0];

  // swap_count = mismatch_count / 2 (integer divide by 2) when count is even
  // For an odd count, swap_count is don't-care per spec (no special handling needed)
  assign swap_count = mismatch_count[2:1];

endmodule