module even_position(
  input [7:0] nums,
  output result
);
  
  wire [7:0] mismatches;
  
  // Check each position for mismatch (LSB of number != LSB of index)
  assign mismatches[0] = nums[0][0] ^ 0;
  assign mismatches[1] = nums[1][0] ^ 1;
  assign mismatches[2] = nums[2][0] ^ 0;
  assign mismatches[3] = nums[3][0] ^ 1;
  assign mismatches[4] = nums[4][0] ^ 0;
  assign mismatches[5] = nums[5][0] ^ 1;
  assign mismatches[6] = nums[6][0] ^ 0;
  assign mismatches[7] = nums[7][0] ^ 1;
  
  // Result is 1 if no mismatches exist (all bits in mismatches are 0)
  assign result = ~|mismatches;
  
endmodule