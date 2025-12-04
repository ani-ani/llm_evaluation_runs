module odd_position_checker(
  input  [7:0] nums [7:0],
  output reg   is_correct
);

  integer i;

  always @(*) begin
    is_correct = 1'b1;
    for (i = 0; i < 8; i = i + 1) begin
      if (i[0] == 1'b0) begin
        // even index: value must be even (LSB == 0)
        if (nums[i][0] != 1'b0)
          is_correct = 1'b0;
      end else begin
        // odd index: value must be odd (LSB == 1)
        if (nums[i][0] != 1'b1)
          is_correct = 1'b0;
      end
    end
  end

endmodule