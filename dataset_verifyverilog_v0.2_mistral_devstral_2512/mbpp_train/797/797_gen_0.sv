module sum_odd_range (
  input [7:0] l,
  input [7:0] r,
  output [15:0] result
);

  wire [7:0] term_r = (r + 1) >> 1;
  wire [7:0] term_l = l >> 1;
  wire [15:0] sq_r = term_r * term_r;
  wire [15:0] sq_l = term_l * term_l;
  assign result = sq_r - sq_l;

endmodule