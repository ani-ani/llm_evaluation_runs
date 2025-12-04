module count_separating_roads(
  input signed [15:0] x1,  // Home x-coordinate (16-bit signed)
  input signed [15:0] y1,  // Home y-coordinate (16-bit signed)
  input signed [15:0] x2,  // University x-coordinate (16-bit signed)
  input signed [15:0] y2,  // University y-coordinate (16-bit signed)
  input signed [15:0] a [0:7],  // Road coefficients (8 elements)
  input signed [15:0] b [0:7],
  input signed [15:0] c [0:7],
  output reg [3:0] count   // Separation count (0-8 roads)
);

  // Behavioral description:
  // For each road i (0-7), compute two values:
  //   home_value      = a[i]*x1 + b[i]*y1 + c[i]
  //   university_value = a[i]*x2 + b[i]*y2 + c[i]
  // If the signs of these two values are different (using MSB as sign indicator),
  // increment the count. Roads with zero coefficients are ignored per problem guarantees.
  // The module processes all 8 roads in parallel using combinational logic.

  // Output count should be the total number of roads where the home and university
  // lie on opposite sides.

  // Implementation note: Use sign bits (home_value[15] ^ university_value[15]) to detect
  // opposite sides and sum all valid cases.

  integer i;
  reg [3:0] sum;

  always @* begin
    sum = 4'b0;
    for (i = 0; i < 8; i = i + 1) begin
      // Compute signed linear forms
      // Products and sums are kept within 16-bit two's complement range; sign is reliable.
      logic signed [15:0] home_value;
      logic signed [15:0] university_value;
      home_value      = a[i] * x1 + b[i] * y1 + c[i];
      university_value = a[i] * x2 + b[i] * y2 + c[i];

      // If signs differ, increment count
      if (home_value[15] ^ university_value[15]) begin
        sum = sum + 1;
      end
    end
    count = sum;
  end

endmodule