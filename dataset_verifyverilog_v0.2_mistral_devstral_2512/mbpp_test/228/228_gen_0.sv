module all_bits_unset_in_range (
  input [31:0] n,
  input [4:0] l,
  input [4:0] r,
  output all_unset
);

  wire [31:0] left_mask = (1 << (l - 1)) - 1;
  wire [31:0] right_mask = (1 << r) - 1;
  wire [31:0] range_mask = right_mask ^ left_mask;

  assign all_unset = (n & range_mask) == 0;

endmodule