module has_close_elements (
  input [7:0][31:0] numbers,
  input [31:0] threshold,
  output result
);

  wire [31:0] diffs [0:13];
  wire [31:0] abs_diffs [0:13];
  wire [0:13] comparisons;

  // Generate all pairwise differences (i < j)
  genvar i, j, k;
  generate
    k = 0;
    for (i = 0; i < 8; i = i + 1) begin : diff_gen
      for (j = i + 1; j < 8; j = j + 1) begin : diff_pair
        assign diffs[k] = numbers[i] - numbers[j];
        k = k + 1;
      end
    end
  endgenerate

  // Compute absolute values
  genvar m;
  generate
    for (m = 0; m < 14; m = m + 1) begin : abs_gen
      assign abs_diffs[m] = (diffs[m][31]) ? (~diffs[m] + 1) : diffs[m];
    end
  endgenerate

  // Compare each absolute difference with threshold
  genvar n;
  generate
    for (n = 0; n < 14; n = n + 1) begin : cmp_gen
      assign comparisons[n] = (abs_diffs[n] < threshold);
    end
  endgenerate

  // OR all comparisons to get final result
  assign result = |comparisons;

endmodule