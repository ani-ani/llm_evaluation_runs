module odd_length_sum(
  input  [7:0] arr_0,
  input  [7:0] arr_1,
  input  [7:0] arr_2,
  input  [7:0] arr_3,
  output reg [7:0] sum
);

  // Precomputed coefficients for N=4:
  // i=0: (((1 * 4) + 1) / 2) = 5/2 = 2 (truncate)
  // i=1: (((2 * 3) + 1) / 2) = 7/2 = 3 (truncate)
  // i=2: (((3 * 2) + 1) / 2) = 7/2 = 3 (truncate)
  // i=3: (((4 * 1) + 1) / 2) = 5/2 = 2 (truncate)

  always @* begin
    sum = (2 * arr_0) + (3 * arr_1) + (3 * arr_2) + (2 * arr_3);
  end

endmodule