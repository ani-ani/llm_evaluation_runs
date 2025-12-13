module xor_odd_pair_counter(
  input  [3:0] A [0:7],
  output [4:0] odd_pair_count
);

  // Count odd elements (LSB = 1)
  wire [3:0] odd_count;

  assign odd_count = (A[0][0]) +
                     (A[1][0]) +
                     (A[2][0]) +
                     (A[3][0]) +
                     (A[4][0]) +
                     (A[5][0]) +
                     (A[6][0]) +
                     (A[7][0]);

  // Even count = 8 - odd_count
  wire [3:0] even_count;
  assign even_count = 4'd8 - odd_count;

  // odd_pair_count = odd_count * even_count
  assign odd_pair_count = odd_count * even_count;

endmodule