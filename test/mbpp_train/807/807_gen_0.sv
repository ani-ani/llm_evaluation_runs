module first_odd_finder(
  input  signed [15:0] nums [7:0],
  output reg [15:0] result
);

  always @* begin
    result = 16'hFFFF; // default to -1

    if (nums[0][0]) begin
      result = nums[0];
    end else if (nums[1][0]) begin
      result = nums[1];
    end else if (nums[2][0]) begin
      result = nums[2];
    end else if (nums[3][0]) begin
      result = nums[3];
    end else if (nums[4][0]) begin
      result = nums[4];
    end else if (nums[5][0]) begin
      result = nums[5];
    end else if (nums[6][0]) begin
      result = nums[6];
    end else if (nums[7][0]) begin
      result = nums[7];
    end
  end

endmodule