module count_lists(
  input  [7:0] sublist_mask,
  output [3:0] count
);

  assign count = sublist_mask[0] + sublist_mask[1] +
                 sublist_mask[2] + sublist_mask[3] +
                 sublist_mask[4] + sublist_mask[5] +
                 sublist_mask[6] + sublist_mask[7];

endmodule