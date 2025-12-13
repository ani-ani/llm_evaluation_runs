module filter_positive(
  input  signed [7:0] array_in [0:15],
  output       [7:0] filtered_out [0:15],
  output       [15:0] valid_mask
);

  genvar i;
  generate
    for (i = 0; i < 16; i = i + 1) begin : gen_filter
      assign valid_mask[i] = (array_in[i] > 0);
      assign filtered_out[i] = valid_mask[i] ? array_in[i] : 8'd0;
    end
  endgenerate

endmodule