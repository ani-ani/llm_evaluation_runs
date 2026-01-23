module below_threshold (
  input [7:0] threshold,
  input [7:0] array [0:7],
  output result
);

  wire [7:0] element_lt_threshold;
  genvar i;

  generate
    for (i = 0; i < 8; i = i + 1) begin : compare_loop
      assign element_lt_threshold[i] = (array[i] < threshold);
    end
  endgenerate

  assign result = &element_lt_threshold;

endmodule