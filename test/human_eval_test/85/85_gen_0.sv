module add_even_at_odd_indices(
  input  [2:0]  length,
  input  [7:0]  lst [7:0],
  output [10:0] sum
);

  wire [10:0] add0 = ((1 < length) && (lst[1][0] == 1'b0)) ? lst[1] : 11'd0;
  wire [10:0] add1 = ((3 < length) && (lst[3][0] == 1'b0)) ? lst[3] : 11'd0;
  wire [10:0] add2 = ((5 < length) && (lst[5][0] == 1'b0)) ? lst[5] : 11'd0;
  wire [10:0] add3 = ((7 < length) && (lst[7][0] == 1'b0)) ? lst[7] : 11'd0;

  assign sum = add0 + add1 + add2 + add3;

endmodule