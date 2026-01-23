module odd_filter (
  input [7:0] array_in [0:7],
  input [2:0] count,
  output reg [7:0] array_out [0:7],
  output reg [2:0] out_count
);

  integer i, j;
  reg [7:0] temp_array [0:7];
  reg [2:0] temp_count;

  // Initialize output array and count
  for (i = 0; i < 8; i = i + 1) begin
    temp_array[i] = 8'b0;
  end
  temp_count = 3'b0;

  // Process input array
  j = 0;
  for (i = 0; i < count; i = i + 1) begin
    if (array_in[i] & 1'b1) begin
      temp_array[j] = array_in[i];
      j = j + 1;
      temp_count = temp_count + 1;
    end
  end

  // Assign to outputs
  for (i = 0; i < 8; i = i + 1) begin
    array_out[i] = temp_array[i];
  end
  out_count = temp_count;

endmodule