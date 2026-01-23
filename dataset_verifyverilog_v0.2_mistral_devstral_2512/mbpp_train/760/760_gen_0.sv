module unique_element_check (
  input [7:0] arr [0:7],
  output result
);

  wire [6:0] comparisons;
  genvar i;
  generate
    for (i = 1; i < 8; i = i + 1) begin : compare_loop
      assign comparisons[i-1] = (arr[i] == arr[0]);
    end
  endgenerate

  assign result = &comparisons;

endmodule