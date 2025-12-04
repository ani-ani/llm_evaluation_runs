module filter_odd_numbers(
  input [7:0] nums [7:0],
  output [7:0] filtered_nums [7:0],
  output [7:0] valid_mask
);

  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : filter_loop
      assign filtered_nums[i] = nums[i][0] ? nums[i] : 8'd0;
      assign valid_mask[i] = nums[i][0] ? 1'b1 : 1'b0;
    end
  endgenerate

endmodule