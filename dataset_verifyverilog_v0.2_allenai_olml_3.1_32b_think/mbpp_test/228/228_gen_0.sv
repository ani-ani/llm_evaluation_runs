module all_bits_unset_in_range(input [31:0] n, input [4:0] l, input [4:0] r, output all_unset);
assign all_unset = (n & (((1 << r) - 1) ^ ((1 << (l - 1)) - 1))) == 0;
endmodule