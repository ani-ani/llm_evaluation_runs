module octagonal_number(
  input reg [7:0] n,         // 8-bit unsigned input (0-255)
  output reg [17:0] oct_num  // 18-bit result (max = 194,565)
);

  // Compute: oct_num = 3*n*n - 2*n
  // Implemented as: ((3 * (n * n)) - (2 * n))
  // Using two multipliers and one subtractor for clarity
  always @* begin
    oct_num = (3 * (n * n)) - (2 * n);
  end

endmodule
