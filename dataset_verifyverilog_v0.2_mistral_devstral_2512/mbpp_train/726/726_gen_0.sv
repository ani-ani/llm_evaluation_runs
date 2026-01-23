module pairwise_mult (
  input [7:0] data_in [0:7],
  output [15:0] data_out [0:6]
);

  genvar i;
  generate
    for (i = 0; i < 7; i = i + 1) begin : pairwise_mult_gen
      assign data_out[i] = data_in[i] * data_in[i+1];
    end
  endgenerate

endmodule