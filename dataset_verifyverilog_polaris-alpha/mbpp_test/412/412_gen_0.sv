module remove_odd_numbers(
  input  [7:0][7:0] data_in,
  output [7:0]      mask_out,
  output [7:0][7:0] data_out
);

  assign data_out = data_in;

  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : gen_mask
      assign mask_out[i] = ~data_in[i][0];
    end
  endgenerate

endmodule