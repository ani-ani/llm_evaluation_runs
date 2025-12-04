module even_xor_pairs_counter(
  input  [7:0] a0,
  input  [7:0] a1,
  input  [7:0] a2,
  input  [7:0] a3,
  input  [7:0] a4,
  input  [7:0] a5,
  input  [7:0] a6,
  input  [7:0] a7,
  output [4:0] count
);

  wire [3:0] even_count;

  assign even_count = (a0[0] ^ 1'b1) +
                      (a1[0] ^ 1'b1) +
                      (a2[0] ^ 1'b1) +
                      (a3[0] ^ 1'b1) +
                      (a4[0] ^ 1'b1) +
                      (a5[0] ^ 1'b1) +
                      (a6[0] ^ 1'b1) +
                      (a7[0] ^ 1'b1);

  // Count of integers with odd LSB is 8 - even_count
  wire [3:0] odd_count;
  assign odd_count = 4'd8 - even_count;

  // Number of pairs with XOR LSB = 0 is:
  // C(even_count, 2) + C(odd_count, 2)
  // = (even_count*(even_count-1))/2 + (odd_count*(odd_count-1))/2

  wire [4:0] c_even;
  wire [4:0] c_odd;

  assign c_even = (even_count * (even_count - 1)) >> 1;
  assign c_odd  = (odd_count  * (odd_count  - 1)) >> 1;

  assign count = c_even + c_odd;

endmodule