module array_min_max_sum(
  input  signed [7:0][15:0] array_input,
  input        [2:0]        array_size,
  output reg signed [16:0]  result
);

  integer i;
  reg signed [15:0] min_val;
  reg signed [15:0] max_val;

  always @* begin
    // Initialize min and max with the first valid element
    min_val = array_input[0];
    max_val = array_input[0];

    // Iterate over the valid elements (from index 1 to array_size-1)
    for (i = 1; i < array_size; i = i + 1) begin
      if (array_input[i] < min_val)
        min_val = array_input[i];
      if (array_input[i] > max_val)
        max_val = array_input[i];
    end

    // Compute signed sum of min and max (17-bit to avoid overflow)
    result = min_val + max_val;
  end

endmodule