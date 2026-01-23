module sum_odd_range(input [7:0] l, input [7:0] r, output [15:0] result);
  assign term_r = ( {16{0}} + r + 1 ) >> 1;
  assign term_l = ( {16{0}} + l ) >> 1;
  assign sq_r = term_r * term_r;
  assign sq_l = term_l * term_l;
  assign result = sq_r - sq_l;
endmodule