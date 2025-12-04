module count_equal_nums(
  input signed [7:0] x,
  input signed [7:0] y,
  input signed [7:0] z,
  output logic [1:0] count
);

  logic eq_xy, eq_yz, eq_xz;

  assign eq_xy = (x == y);
  assign eq_yz = (y == z);
  assign eq_xz = (x == z);

  assign count = (eq_xy & eq_yz & eq_xz) ? 2'b11 : (eq_xy | eq_yz | eq_xz) ? 2'b10 : 2'b00;

endmodule