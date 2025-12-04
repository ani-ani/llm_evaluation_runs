module sum_of_squares(
  input  [7:0]  n,
  output reg [24:0] sum_squares
);

  // Intermediate wires/regs sized to avoid overflow while staying efficient
  reg [8:0]  n_plus_1;      // n+1 (max 256)
  reg [8:0]  two_n;         // 2*n (max 510)
  reg [9:0]  two_n_plus_1;  // 2*n+1 (max 511)
  reg [26:0] mult0;         // two_n * n_plus_1 (<= 510*256=130560 < 2^17) sized generously
  reg [36:0] mult1;         // mult0 * two_n_plus_1 (fits within 37 bits)

  always @* begin
    // Compute basic terms
    n_plus_1     = n + 8'd1;
    two_n        = {n,1'b0};          // 2*n
    two_n_plus_1 = {n,1'b0} + 10'd1;  // 2*n + 1

    // Multiply terms (combinational)
    mult0 = two_n * n_plus_1;
    mult1 = mult0 * two_n_plus_1;

    // Final division by 3 (integer division; exact for all valid n)
    sum_squares = mult1 / 3;
  end

endmodule