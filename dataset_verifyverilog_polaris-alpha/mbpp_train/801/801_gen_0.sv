module count_equal_nums(
  input  signed [7:0] x,
  input  signed [7:0] y,
  input  signed [7:0] z,
  output       [1:0] count
);

  wire xy_eq = (x == y);
  wire yz_eq = (y == z);
  wire xz_eq = (x == z);

  // all three equal -> 3, exactly one pair equal -> 2, else 0
  assign count = (xy_eq & yz_eq) ? 2'b11 :
                 (xy_eq | yz_eq | xz_eq) ? 2'b10 :
                 2'b00;

endmodule