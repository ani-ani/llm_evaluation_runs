module odd_index_filter (
  input [7:0] char_array [0:15],
  input [3:0] length,
  output [7:0] result [0:7],
  output [3:0] result_length
);

  integer i, j;
  
  // Initialize result array to all zeros
  for (i = 0; i < 8; i = i + 1) begin
    result[i] = 8'h00;
  end
  
  // Filter characters at even indices
  j = 0;
  for (i = 0; i < length; i = i + 1) begin
    if (i % 2 == 0) begin
      result[j] = char_array[i];
      j = j + 1;
    end
  end
  
  // Calculate result length
  result_length = (length + 1) / 2;

endmodule