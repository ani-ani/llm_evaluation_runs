module sum_cube_difference(
  input  [7:0]  n,
  output [29:0] result
);

  // Intermediate signals sized to avoid overflow
  wire [8:0]   n_plus_1;   // n + 1 (max 256)
  wire [16:0]  prod;       // n * (n + 1) (max 255*256 = 65280 < 2^16)
  wire [15:0]  sum_s;      // Sum_S = (n*(n+1))/2 (max 32640 < 2^16)
  wire [15:0]  sum_s_minus1;
  wire [31:0]  full_mult;  // sum_s * (sum_s - 1) (max ~1.06e9 < 2^30)

  assign n_plus_1    = n + 8'd1;
  assign prod        = n * n_plus_1;
  assign sum_s       = prod[16:1];       // divide by 2 (unsigned)
  assign sum_s_minus1 = sum_s - 16'd1;
  assign full_mult   = sum_s * sum_s_minus1;
  assign result      = full_mult[29:0];  // 30-bit unsigned result

endmodule