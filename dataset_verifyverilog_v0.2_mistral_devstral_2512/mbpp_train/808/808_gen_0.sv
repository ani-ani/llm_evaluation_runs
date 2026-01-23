module tuple_contains_k (
  input [7:0] k,
  input [7:0] data [0:7],
  output found
);

  wire [7:0] matches;
  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : compare_loop
      assign matches[i] = (data[i] == k);
    end
  endgenerate

  assign found = |matches;

endmodule