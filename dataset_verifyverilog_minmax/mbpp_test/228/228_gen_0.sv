module bit_range_unset_check(
  input reg [7:0] n,
  input reg [3:0] l,
  input reg [3:0] r,
  output logic result
);
  // Mask selecting bits [l..r], 1-based indexing (LSB is bit 1)
  // Using 9 bits internally to handle the case r = 8 (no overflow)
  logic [7:0] mask;
  logic [8:0] left_full, right_full;

  assign left_full  = (9'b1 << (l - 1)) - 1; // bits [0..l-2]
  assign right_full = (9'b1 << r) - 1;      // bits [0..r-1]
  assign mask = logic'(right_full ^ left_full); // bits [l-1..r-1]

  assign result = ((n & mask) == 8'h0) ? 1'b1 : 1'b0;
endmodule