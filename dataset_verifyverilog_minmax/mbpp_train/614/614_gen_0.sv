module tuple_list_sum (
  input [2:0] valid_matrix [0:2][0:2], // 3x3 validity matrix (1=valid element)
  input [7:0] data_matrix [0:2][0:2],    // 3x3 data elements (8-bit values)
  output reg [11:0] total_sum            // Cumulative sum of all valid elements
);

  // Compute the sum of all valid entries
  always @(*) begin
    total_sum = 12'h000;
    for (int i = 0; i < 3; i = i + 1) begin
      for (int j = 0; j < 3; j = j + 1) begin
        if (valid_matrix[i][j] == 1'b1) begin
          total_sum = total_sum + data_matrix[i][j];
        end
      end
    end
  end

endmodule
