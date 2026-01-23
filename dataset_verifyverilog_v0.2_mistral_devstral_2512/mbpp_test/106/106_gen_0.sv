module list_append (
  input [7:0] list_data [0:7],
  input [2:0] list_len,
  input [7:0] tuple_data [0:7],
  input [2:0] tuple_len,
  output [7:0] result [0:7],
  output [2:0] result_len
);

  integer i;
  integer j;
  integer k;

  // Calculate result length (capped at 8)
  assign result_len = (tuple_len + list_len) > 8 ? 8 : (tuple_len + list_len);

  // Initialize result array
  for (i = 0; i < 8; i = i + 1) begin
    result[i] = 8'b0;
  end

  // Copy tuple data to result
  for (j = 0; j < tuple_len; j = j + 1) begin
    result[j] = tuple_data[j];
  end

  // Copy list data to result (truncate if necessary)
  for (k = 0; k < list_len; k = k + 1) begin
    if ((tuple_len + k) < 8) begin
      result[tuple_len + k] = list_data[k];
    end
  end

endmodule