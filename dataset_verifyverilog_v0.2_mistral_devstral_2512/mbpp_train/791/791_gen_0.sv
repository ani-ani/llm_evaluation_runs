module remove_nested (
  input [7:0] data_in [0:7],
  output [7:0] data_out [0:7]
);

  integer i, j;
  reg [7:0] temp_out [0:7];

  // Initialize all output elements to 8'hFF
  for (i = 0; i < 8; i = i + 1) begin
    temp_out[i] = 8'hFF;
  end

  // Iterate through input array and filter out nested tuples
  j = 0;
  for (i = 0; i < 8; i = i + 1) begin
    if (data_in[i] != 8'hFF) begin
      temp_out[j] = data_in[i];
      j = j + 1;
    end
  end

  // Assign to output
  for (i = 0; i < 8; i = i + 1) begin
    data_out[i] = temp_out[i];
  end

endmodule