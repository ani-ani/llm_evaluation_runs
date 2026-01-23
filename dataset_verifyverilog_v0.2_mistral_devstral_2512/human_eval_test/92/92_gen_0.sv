module any_int (
  input signed [15:0] x,
  input signed [15:0] y,
  input signed [15:0] z,
  output result
);

  wire signed [16:0] y_plus_z = y + z;
  wire signed [16:0] x_plus_z = x + z;
  wire signed [16:0] x_plus_y = x + y;

  wire cond1 = (x == y_plus_z);
  wire cond2 = (y == x_plus_z);
  wire cond3 = (z == x_plus_y);

  assign result = cond1 | cond2 | cond3;

endmodule