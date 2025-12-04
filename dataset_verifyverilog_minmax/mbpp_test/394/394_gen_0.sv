module check_distinct (
  input [7:0] tuple [7:0], // 8 elements of 8-bit values
  output reg is_distinct   // 1 if all elements unique, 0 otherwise
);

  // Compute duplicate flags by comparing each element with all previous elements
  // Parallel comparisons:
  // Element 1 vs 0
  // Element 2 vs 0,1
  // ...
  // Element 7 vs 0..6
  // OR all duplicate flags, then invert for is_distinct
  wire duplicate;

  assign duplicate =
    (tuple[1] == tuple[0]) |
    (tuple[2] == tuple[0]) | (tuple[2] == tuple[1]) |
    (tuple[3] == tuple[0]) | (tuple[3] == tuple[1]) | (tuple[3] == tuple[2]) |
    (tuple[4] == tuple[0]) | (tuple[4] == tuple[1]) | (tuple[4] == tuple[2]) | (tuple[4] == tuple[3]) |
    (tuple[5] == tuple[0]) | (tuple[5] == tuple[1]) | (tuple[5] == tuple[2]) | (tuple[5] == tuple[3]) | (tuple[5] == tuple[4]) |
    (tuple[6] == tuple[0]) | (tuple[6] == tuple[1]) | (tuple[6] == tuple[2]) | (tuple[6] == tuple[3]) | (tuple[6] == tuple[4]) | (tuple[6] == tuple[5]) |
    (tuple[7] == tuple[0]) | (tuple[7] == tuple[1]) | (tuple[7] == tuple[2]) | (tuple[7] == tuple[3]) | (tuple[7] == tuple[4]) | (tuple[7] == tuple[5]) | (tuple[7] == tuple[6]);

  always @* begin
    is_distinct = ~duplicate; // Invert: 1 if no duplicates found, 0 otherwise
  end

endmodule