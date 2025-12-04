module common_element(
  input [7:0][7:0] list1,
  input [7:0] list1_valid,
  input [7:0][7:0] list2,
  input [7:0] list2_valid,
  output logic result
);

  // For each element in list1, determine if any valid element in list2 matches it
  wire [7:0] match_per_i;
  genvar i, j;
  generate
    for (i = 0; i < 8; i = i + 1) begin : per_i
      wire [7:0] any_j_eq;
      for (j = 0; j < 8; j = j + 1) begin : per_j
        assign any_j_eq[j] = list2_valid[j] & (list1[i] == list2[j]);
      end
      // Reduction OR across j to see if any j matches list1[i]
      assign match_per_i[i] = |any_j_eq;
    end
  endgenerate

  // Only consider positions in list1 that are valid
  wire [7:0] active_match_per_i;
  genvar k;
  generate
    for (k = 0; k < 8; k = k + 1) begin : filter_valid
      assign active_match_per_i[k] = list1_valid[k] & match_per_i[k];
    end
  endgenerate

  // Final result: OR across all active i positions
  assign result = |active_match_per_i;

endmodule