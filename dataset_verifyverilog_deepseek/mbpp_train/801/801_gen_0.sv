module count_equal_nums(
  input reg signed [7:0] x,
  input reg signed [7:0] y,
  input reg signed [7:0] z,
  output wire [1:0] count
);
  wire xy_eq = (x == y);
  wire yz_eq = (y == z);
  wire xz_eq = (x == z);
  wire all_equal = xy_eq && yz_eq;
  assign count = all_equal ? 2'b11 : (xy_eq || yz_eq || xz_eq) ? 2'b10 : 2'b00;
endmodule