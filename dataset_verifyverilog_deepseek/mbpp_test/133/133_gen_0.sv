module sum_negative_numbers(input signed [9:0][15:0] nums, output logic signed [15:0] sum_neg);
  always_comb begin
    sum_neg = 16'sd0;
    for (int i = 0; i < 10; i++) begin
      if (nums[i] < 0) sum_neg += nums[i];
    end
  end
endmodule