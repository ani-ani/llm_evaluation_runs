module centered_hexagonal(
  input  [3:0] n,
  output [9:0] hex_num
);

  wire [4:0] n_minus_1;   // up to 15 -> 4'b1111, minus 1 fits in 4 bits, use 5 for safety
  wire [8:0] prod_n_nm1;  // max 15*14 = 210 -> needs 8 bits, use 9 for intermediate
  wire [9:0] triple_prod; // 3 * 210 = 630 -> needs 10 bits

  assign n_minus_1  = n - 1'b1;
  assign prod_n_nm1 = n * n_minus_1;
  assign triple_prod = 3 * prod_n_nm1;
  assign hex_num = triple_prod + 10'd1;

endmodule