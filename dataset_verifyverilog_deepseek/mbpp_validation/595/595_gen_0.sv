module min_swaps (input [3:0] str1, input [3:0] str2, output [2:0] swap_count, output error);
  wire [3:0] diff = str1 ^ str2;
  wire [2:0] mismatch_count = diff[0] + diff[1] + diff[2] + diff[3];
  assign error = mismatch_count[0];
  assign swap_count = {1'b0, mismatch_count[2:1]};
endmodule