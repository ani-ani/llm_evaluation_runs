module element_counter (
  input reg [7:0] target_element,
  input reg [3:0][3:0][7:0] sublists,
  input reg [3:0][3:0] valid_mask,
  output reg [2:0] count
);

  // Intermediate wires for each sublist's match status
  wire [3:0] sublist_match;
  
  // Sublist 0 match detection
  assign sublist_match[0] = (valid_mask[0][0] && (sublists[0][0] == target_element)) ||
                            (valid_mask[0][1] && (sublists[0][1] == target_element)) ||
                            (valid_mask[0][2] && (sublists[0][2] == target_element)) ||
                            (valid_mask[0][3] && (sublists[0][3] == target_element));
  
  // Sublist 1 match detection
  assign sublist_match[1] = (valid_mask[1][0] && (sublists[1][0] == target_element)) ||
                            (valid_mask[1][1] && (sublists[1][1] == target_element)) ||
                            (valid_mask[1][2] && (sublists[1][2] == target_element)) ||
                            (valid_mask[1][3] && (sublists[1][3] == target_element));
  
  // Sublist 2 match detection
  assign sublist_match[2] = (valid_mask[2][0] && (sublists[2][0] == target_element)) ||
                            (valid_mask[2][1] && (sublists[2][1] == target_element)) ||
                            (valid_mask[2][2] && (sublists[2][2] == target_element)) ||
                            (valid_mask[2][3] && (sublists[2][3] == target_element));
  
  // Sublist 3 match detection
  assign sublist_match[3] = (valid_mask[3][0] && (sublists[3][0] == target_element)) ||
                            (valid_mask[3][1] && (sublists[3][1] == target_element)) ||
                            (valid_mask[3][2] && (sublists[3][2] == target_element)) ||
                            (valid_mask[3][3] && (sublists[3][3] == target_element));
  
  // Count the number of sublists with matches
  always @(*) begin
    count = 3'b0;
    if (sublist_match[0]) count = count + 1;
    if (sublist_match[1]) count = count + 1;
    if (sublist_match[2]) count = count + 1;
    if (sublist_match[3]) count = count + 1;
  end
  
endmodule