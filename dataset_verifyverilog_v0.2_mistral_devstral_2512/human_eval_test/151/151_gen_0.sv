module double_the_difference (
  input [7:0] nums [0:7],
  output [15:0] result
);

  wire [15:0] squares [0:7];
  wire [15:0] contributions [0:7];
  integer i;

  // Generate squares for each number
  genvar g;
  generate
    for (g = 0; g < 8; g = g + 1) begin : square_gen
      assign squares[g] = nums[g] * nums[g];
    end
  endgenerate

  // Check conditions and compute contributions
  always @(*) begin
    for (i = 0; i < 8; i = i + 1) begin
      if (nums[i][7] == 0 && nums[i][0] == 1) begin
        contributions[i] = squares[i];
      end else begin
        contributions[i] = 0;
      end
    end
  end

  // Sum all contributions
  assign result = contributions[0] + contributions[1] + contributions[2] + contributions[3] +
                  contributions[4] + contributions[5] + contributions[6] + contributions[7];

endmodule