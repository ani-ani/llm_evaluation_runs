module element_counter(
  input  [7:0]            target_element,
  input  [3:0][3:0][7:0]  sublists,
  input  [3:0][3:0]       valid_mask,
  output [2:0]            count
);

  wire match0 = ((valid_mask[0][0] & (sublists[0][0] == target_element)) |
                 (valid_mask[0][1] & (sublists[0][1] == target_element)) |
                 (valid_mask[0][2] & (sublists[0][2] == target_element)) |
                 (valid_mask[0][3] & (sublists[0][3] == target_element)));

  wire match1 = ((valid_mask[1][0] & (sublists[1][0] == target_element)) |
                 (valid_mask[1][1] & (sublists[1][1] == target_element)) |
                 (valid_mask[1][2] & (sublists[1][2] == target_element)) |
                 (valid_mask[1][3] & (sublists[1][3] == target_element)));

  wire match2 = ((valid_mask[2][0] & (sublists[2][0] == target_element)) |
                 (valid_mask[2][1] & (sublists[2][1] == target_element)) |
                 (valid_mask[2][2] & (sublists[2][2] == target_element)) |
                 (valid_mask[2][3] & (sublists[2][3] == target_element)));

  wire match3 = ((valid_mask[3][0] & (sublists[3][0] == target_element)) |
                 (valid_mask[3][1] & (sublists[3][1] == target_element)) |
                 (valid_mask[3][2] & (sublists[3][2] == target_element)) |
                 (valid_mask[3][3] & (sublists[3][3] == target_element)));

  assign count = match0 + match1 + match2 + match3;

endmodule