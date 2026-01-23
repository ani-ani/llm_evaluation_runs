module list_filter (
  input [2:0][7:0] list1,
  input [2:0][7:0] list2,
  input [2:0] valid2,
  output [2:0][7:0] result,
  output [2:0] result_valid
);

  wire [7:0] match [0:7]; // match[i] = 1 if list1[i] matches any valid list2 element
  wire [7:0] keep [0:7];  // keep[i] = 1 if list1[i] should be kept in result
  wire [7:0] result_mask; // bitmask of kept elements (before compacting)

  // Generate match signals for each list1 element
  genvar i, j;
  generate
    for (i = 0; i < 8; i = i + 1) begin : gen_match
      wire [7:0] comparisons;
      for (j = 0; j < 8; j = j + 1) begin : gen_comparison
        assign comparisons[j] = (valid2[j] && (list1[i] == list2[j]));
      end
      assign match[i] = |comparisons;
    end
  endgenerate

  // Determine which elements to keep (invert match)
  genvar k;
  generate
    for (k = 0; k < 8; k = k + 1) begin : gen_keep
      assign keep[k] = ~|match[k];
    end
  endgenerate

  // Create result mask (which positions are kept)
  assign result_mask = {keep[7], keep[6], keep[5], keep[4], keep[3], keep[2], keep[1], keep[0]};

  // Generate result list (with zeros for removed elements)
  // and result_valid mask (same as result_mask for this implementation)
  assign result[0] = keep[0] ? list1[0] : 8'b0;
  assign result[1] = keep[1] ? list1[1] : 8'b0;
  assign result[2] = keep[2] ? list1[2] : 8'b0;
  assign result[3] = keep[3] ? list1[3] : 8'b0;
  assign result[4] = keep[4] ? list1[4] : 8'b0;
  assign result[5] = keep[5] ? list1[5] : 8'b0;
  assign result[6] = keep[6] ? list1[6] : 8'b0;
  assign result[7] = keep[7] ? list1[7] : 8'b0;

  assign result_valid = result_mask;

endmodule