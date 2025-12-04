module filter_odd_numbers (
  input [7:0] nums [7:0],
  output [7:0] filtered_nums [7:0],
  output [7:0] valid_mask
);

  always_comb begin
    for (int i = 0; i < 8; i++) begin
      filtered_nums[i] = nums[i][0] ? nums[i] : 8'd0;
      valid_mask[i] = nums[i][0];
    end
  end

endmodule