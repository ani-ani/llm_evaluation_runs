module filter_positive(
  input signed [7:0] array_in [0:15],
  output reg [7:0] filtered_out [0:15],
  output reg [15:0] valid_mask
);
  always_comb begin
    for (int i = 0; i < 16; i++) begin
      if (array_in[i] > 0) begin
        filtered_out[i] = array_in[i];
        valid_mask[i] = 1'b1;
      end else begin
        filtered_out[i] = 8'b0;
        valid_mask[i] = 1'b0;
      end
    end
  end
endmodule