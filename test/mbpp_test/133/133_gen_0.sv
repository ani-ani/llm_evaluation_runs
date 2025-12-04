module sum_negative_numbers(
  input  signed [15:0] nums [9:0],
  output signed [15:0] sum_neg
);

  reg signed [15:0] sum;
  integer i;

  always @* begin
    sum = 16'sd0;
    for (i = 0; i < 10; i = i + 1) begin
      if (nums[i][15] == 1'b1)
        sum = sum + nums[i];
    end
  end

  assign sum_neg = sum;

endmodule