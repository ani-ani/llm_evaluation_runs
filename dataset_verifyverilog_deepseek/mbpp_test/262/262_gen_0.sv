module array_splitter (
  input [63:0] flat_array,
  input [2:0] L,
  output [63:0] part1,
  output [63:0] part2
);
  assign part1 = flat_array & ((64'b1 << (L * 8)) - 1);
  assign part2 = flat_array >> (L * 8);
endmodule