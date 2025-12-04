module bit_range_unset_check (
  input [7:0] n,
  input [3:0] l,
  input [3:0] r,
  output result
);
  wire [7:0] mask_left = (1'b1 << r) - 1'b1;
  wire [7:0] mask_right = (1'b1 << (l - 1'b1)) - 1'b1;
  wire [7:0] mask = mask_left ^ mask_right;
  wire [7:0] masked_value = n & mask;
  assign result = (masked_value == 8'b0) ? 1'b1 : 1'b0;
endmodule