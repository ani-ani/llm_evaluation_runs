module close_element_checker (
  input [127:0] numbers_packed,
  input [15:0] threshold_q8_8,
  output logic has_close_pair
);

  // Unpack 8 x Q8.8 numbers (16-bit each) from the 128-bit packed input
  logic [15:0] nums [0:7];
  assign nums[0] = numbers_packed[15:0];
  assign nums[1] = numbers_packed[31:16];
  assign nums[2] = numbers_packed[47:32];
  assign nums[3] = numbers_packed[63:48];
  assign nums[4] = numbers_packed[79:64];
  assign nums[5] = numbers_packed[95:80];
  assign nums[6] = numbers_packed[111:96];
  assign nums[7] = numbers_packed[127:112];

  // Check all pairs for |a - b| < threshold
  always_comb begin
    has_close_pair = 1'b0;
    for (int i = 0; i < 7; i++) begin
      for (int j = i + 1; j < 8; j++) begin
        // Treat Q8.8 values as signed integers for the difference
        automatic logic signed [15:0] a = nums[i];
        automatic logic signed [15:0] b = nums[j];
        automatic logic [15:0] adiff = a - b;
        adiff = adiff[15] ? ~adiff + 1 : adiff; // absolute value (|a - b|)
        if (adiff < threshold_q8_8) begin
          has_close_pair = 1'b1;
        end
      end
    end
  end

endmodule
