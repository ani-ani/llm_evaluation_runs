module array_min_max_sum (
  input reg [7:0][15:0] array_input,
  input reg [2:0] array_size,
  output reg [16:0] result
);

  // Signed helpers for finding min/max
  reg signed [15:0] min_val;
  reg signed [15:0] max_val;
  integer i;

  always @* begin
    // Initialize min and max using full range of 16-bit signed values
    min_val = 16'h7FFF; // max positive 16-bit signed value
    max_val = 16'h8000; // most negative 16-bit signed value

    // Iterate through the first array_size elements
    for (i = 0; i < 8; i = i + 1) begin
      if (i < array_size) begin
        if (array_input[i] < min_val) min_val = array_input[i];
        if (array_input[i] > max_val) max_val = array_input[i];
      end
    end

    // Compute signed sum (17 bits to avoid overflow)
    result = $signed(min_val) + $signed(max_val);
  end

endmodule
