module array_intersection(
  input      [2:0] len1,
  input      [2:0] len2,
  input      [5:0] array1 [0:7],
  input      [5:0] array2 [0:7],
  output reg [5:0] result [0:7],
  output reg [2:0] result_len
);

  integer i, j;
  reg match_found;

  always @(*) begin
    // Default outputs
    result_len = 3'd0;
    for (i = 0; i < 8; i = i + 1) begin
      result[i] = 6'd0;
    end

    // For each element in array2 up to len2
    for (i = 0; i < 8; i = i + 1) begin
      if (i < len2) begin
        match_found = 1'b0;
        // Check against array1 up to len1
        for (j = 0; j < 8; j = j + 1) begin
          if ((j < len1) && (array2[i] == array1[j])) begin
            match_found = 1'b1;
          end
        end
        // If a match is found, add to result in order of array2
        if (match_found && (result_len < 3'd8)) begin
          result[result_len] = array2[i];
          result_len = result_len + 1'b1;
        end
      end
    end
  end

endmodule