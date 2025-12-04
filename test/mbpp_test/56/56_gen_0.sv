module rev_checker(
  input  [7:0] num,
  output       check
);

  // Extract decimal digits using modular arithmetic
  // hundreds = num / 100
  // tens     = (num % 100) / 10
  // units    = num % 10

  wire [7:0] hundreds;
  wire [7:0] tens;
  wire [7:0] units;

  assign hundreds = num / 8'd100;
  assign tens     = (num % 8'd100) / 8'd10;
  assign units    = num % 8'd10;

  // reversed_num = units*100 + tens*10 + hundreds
  // Max reversed_num = 552 < 2^10 → use 10 bits

  wire [9:0] reversed_num;
  assign reversed_num = (units * 10'd100) + (tens * 10'd10) + hundreds;

  // Compute 2 * reversed_num and num + 1 for comparison
  wire [10:0] twice_reversed;
  wire [8:0]  num_plus_one;

  assign twice_reversed = {1'b0, reversed_num} << 1; // 2 * reversed_num
  assign num_plus_one   = {1'b0, num} + 9'd1;       // num + 1

  // Compare; extend num_plus_one to 11 bits for equality check
  assign check = (twice_reversed == {2'b00, num_plus_one});

endmodule