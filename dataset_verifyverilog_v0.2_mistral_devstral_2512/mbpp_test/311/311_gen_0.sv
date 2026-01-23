module set_left_most_unset_bit (
  input [15:0] n,
  output [15:0] result
);

  wire [15:0] mask = ~n;
  wire [15:0] priority_mask = 16'b0000_0000_0000_0001;
  wire [15:0] temp_result;

  genvar i;
  generate
    for (i = 15; i >= 0; i = i - 1) begin : find_leftmost_unset
      if (i == 15) begin
        assign priority_mask[i] = mask[i];
      end else begin
        assign priority_mask[i] = mask[i] & ~|mask[15:i+1];
      end
    end
  endgenerate

  assign temp_result = n | priority_mask;
  assign result = (n == 16'hFFFF) ? n : temp_result;

endmodule