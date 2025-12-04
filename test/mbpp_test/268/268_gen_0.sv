module star_number(
  input  [4:0]  n,
  output [10:0] star_num
);

  wire [5:0]  n_ext      = {1'b0, n};          // extend to avoid sign/overflow issues
  wire [5:0]  n_minus_1  = n_ext - 6'd1;
  wire [10:0] mult_term  = n_ext * n_minus_1;  // max 16*15=240 < 2^8, fits in 11 bits
  wire [10:0] six_mult   = mult_term * 11'd6;  // max 6*240=1440 < 2^11 (2048)

  assign star_num = six_mult + 11'd1;

endmodule