module next_perfect_square (
  input [15:0] N,
  output [15:0] result
);

  reg [7:0] sqrt_N;
  reg [7:0] nextN;
  reg [15:0] square;

  // Compute integer square root (floor(sqrt(N)))
  always @* begin
    sqrt_N = 0;
    if (N >= 1) begin
      // Binary search for square root
      reg [7:0] low = 0;
      reg [7:0] high = 255;
      reg [7:0] mid;
      reg [15:0] mid_sq;

      while (low <= high) begin
        mid = (low + high) >> 1;
        mid_sq = mid * mid;

        if (mid_sq <= N) begin
          sqrt_N = mid;
          low = mid + 1;
        end else begin
          high = mid - 1;
        end
      end
    end
  end

  // Compute nextN and its square
  assign nextN = sqrt_N + 1;
  assign square = nextN * nextN;

  // Handle edge case where square overflows 16 bits
  assign result = (square == 65536) ? 0 : square;

endmodule