module common_element (
  input [7:0] list1 [0:4],
  input [7:0] list2 [0:4],
  output result
);

  wire [24:0] comparisons;

  // Generate all 25 comparisons
  genvar i, j;
  generate
    for (i = 0; i < 5; i = i + 1) begin : list1_loop
      for (j = 0; j < 5; j = j + 1) begin : list2_loop
        assign comparisons[i*5 + j] = (list1[i] == list2[j]);
      end
    end
  endgenerate

  // OR-reduce all comparison results
  assign result = |comparisons;

endmodule