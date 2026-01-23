module choose_num (
  input [15:0] x,
  input [15:0] y,
  output [15:0] result
);

  wire [15:0] largest_even;
  wire x_gt_y = (x > y);
  wire y_is_even = (y[0] == 0);
  wire largest_even_ge_x;

  assign largest_even = y_is_even ? y : y - 1;
  assign largest_even_ge_x = (largest_even >= x);

  assign result = x_gt_y ? 16'hFFFF : (largest_even_ge_x ? largest_even : 16'hFFFF);

endmodule