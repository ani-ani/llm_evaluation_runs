module hexagonal_number(
  input [7:0] n,
  output [15:0] result
);
  // Compute temp = 2*n - 1
  wire [8:0] temp;
  // temp = 2 * n - 1. 2*n is 9 bits (max 510), minus 1 fits in 9 bits.
  assign temp = ({1'b0, n} << 1) - 1'b1;

  // Compute result = n * temp
  // Max n=255, max temp=509 -> product=129795 (17 bits)
  // Module output is 16 bits, truncating MSB.
  wire [16:0] full_result;
  assign full_result = n * temp;
  assign result = full_result[15:0];

endmodule
