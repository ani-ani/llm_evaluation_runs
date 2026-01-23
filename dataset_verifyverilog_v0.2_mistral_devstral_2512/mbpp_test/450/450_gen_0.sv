module string_extractor (
  input [7:0][7:0] strings,
  input [2:0] target_len,
  input [4:0] valid_mask,
  output [7:0][7:0] result,
  output [4:0] result_mask
);

  integer i, j, k;
  integer str_len;
  integer result_idx;

  // Initialize result array and mask
  for (i = 0; i < 8; i = i + 1) begin
    for (j = 0; j < 8; j = j + 1) begin
      result[i][j] = 8'b0;
    end
  end
  result_mask = 5'b0;

  result_idx = 0;

  // Process each of the 5 input strings
  for (i = 0; i < 5; i = i + 1) begin
    if (valid_mask[i]) begin
      // Calculate actual string length
      str_len = 0;
      for (j = 0; j < 8; j = j + 1) begin
        if (strings[i][j] == 8'b0) begin
          break;
        end
        str_len = str_len + 1;
      end

      // Check if length matches target
      if (str_len == target_len) begin
        // Copy string to result
        for (k = 0; k < 8; k = k + 1) begin
          result[result_idx][k] = strings[i][k];
        end
        result_mask[result_idx] = 1'b1;
        result_idx = result_idx + 1;
      end
    end
  end

endmodule