module array_transpose (
  input [7:0] data_in [0:7][0:1],
  input [2:0] num_pairs,
  output [7:0] col0 [0:7],
  output [7:0] col1 [0:7]
);

  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : transpose_loop
      assign col0[i] = (i < num_pairs) ? data_in[i][0] : 8'd0;
      assign col1[i] = (i < num_pairs) ? data_in[i][1] : 8'd0;
    end
  endgenerate

endmodule