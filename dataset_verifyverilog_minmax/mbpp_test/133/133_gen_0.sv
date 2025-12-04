module sum_negative_numbers (
  input wire [15:0] nums [9:0], // 10 elements of 16-bit signed integers
  output reg [15:0] sum_neg     // 16-bit signed sum of negative numbers
);

  // Combinational logic: sum only numbers with MSB=1 (negative)
  always @* begin
    sum_neg = 16'sb0; // default: no negative numbers
    for (int i = 0; i < 10; i++) begin
      if (nums[i][15]) // negative (two's complement)
        sum_neg = sum_neg + nums[i];
    end
  end

endmodule