module perfect_square_check (
  input [7:0] number,
  output reg is_perfect_square
);

  wire [7:0] squares [1:15];
  integer i;

  // Precompute all squares from 1 to 15
  genvar j;
  generate
    for (j = 1; j <= 15; j = j + 1) begin : square_gen
      assign squares[j] = j * j;
    end
  endgenerate

  // Check if number is 0 (special case)
  wire is_zero = (number == 8'd0);

  // Check if number matches any precomputed square
  wire [15:1] matches = '0;
  for (i = 1; i <= 15; i = i + 1) begin
    matches[i] = (number == squares[i]);
  end

  // Combine all matches with OR
  wire any_match = |matches;

  // Final output: 1 if number is 0 or matches any square
  always @* begin
    is_perfect_square = is_zero || any_match;
  end

endmodule