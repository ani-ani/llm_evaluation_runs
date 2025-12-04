module any_int_check(
  input  signed [7:0] x,
  input  signed [7:0] y,
  input  signed [7:0] z,
  output       [0:0] result
);

  wire signed [8:0] sum_yz = y + z;
  wire signed [8:0] sum_xz = x + z;
  wire signed [8:0] sum_xy = x + y;

  assign result = (x === sum_yz[7:0] && sum_yz[8] == sum_yz[7]) ||
                  (y === sum_xz[7:0] && sum_xz[8] == sum_xz[7]) ||
                  (z === sum_xy[7:0] && sum_xy[8] == sum_xy[7]);

endmodule