module first_odd_finder (
  input [15:0] nums [0:7], // 8-element array of 16-bit signed integers
  output [15:0] result
);

  // Purely combinational: find the first odd number (LSB == 1) in nums[0..7]
  // If none found, return 16'hFFFF (-1 in two's complement)
  always_comb begin
    result = 16'hFFFF; // default: no odd found
    for (int i = 0; i < 8; i++) begin
      if (nums[i][0] == 1'b1) begin
        result = nums[i];
        break;
      end
    end
  end

endmodule