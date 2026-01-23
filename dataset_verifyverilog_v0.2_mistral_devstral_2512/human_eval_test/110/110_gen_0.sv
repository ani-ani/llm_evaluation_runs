module exchange_checker (
  input [7:0] lst1 [0:7],
  input [7:0] lst2 [0:7],
  output reg result
);

  // Detect odd numbers in lst1 and lst2
  wire [7:0] odd_in = {lst1[7][0], lst1[6][0], lst1[5][0], lst1[4][0], lst1[3][0], lst1[2][0], lst1[1][0], lst1[0][0]};
  wire [7:0] odd_out = {lst2[7][0], lst2[6][0], lst2[5][0], lst2[4][0], lst2[3][0], lst2[2][0], lst2[1][0], lst2[0][0]};

  // Count odd numbers using parallel reduction
  wire [2:0] odd_in_count = odd_in[7] + odd_in[6] + odd_in[5] + odd_in[4] + odd_in[3] + odd_in[2] + odd_in[1] + odd_in[0];
  wire [2:0] odd_out_count = odd_out[7] + odd_out[6] + odd_out[5] + odd_out[4] + odd_out[3] + odd_out[2] + odd_out[1] + odd_out[0];

  // Compare counts
  assign result = (odd_in_count <= odd_out_count) ? 1'b1 : 1'b0;

endmodule