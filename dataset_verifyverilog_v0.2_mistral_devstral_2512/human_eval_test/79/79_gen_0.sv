module decimal_to_binary (
  input [7:0] decimal,
  output [71:0] binary_str
);

  wire [7:0] char0 = 8'h64; // 'd'
  wire [7:0] char1 = 8'h62; // 'b'
  wire [7:0] char9 = 8'h64; // 'd'
  wire [7:0] char10 = 8'h62; // 'b'

  wire [7:0] binary_digits [0:7];
  integer i;

  // Convert decimal to 8-bit binary representation
  assign binary_digits[0] = decimal[7] ? 8'h31 : 8'h30;
  assign binary_digits[1] = decimal[6] ? 8'h31 : 8'h30;
  assign binary_digits[2] = decimal[5] ? 8'h31 : 8'h30;
  assign binary_digits[3] = decimal[4] ? 8'h31 : 8'h30;
  assign binary_digits[4] = decimal[3] ? 8'h31 : 8'h30;
  assign binary_digits[5] = decimal[2] ? 8'h31 : 8'h30;
  assign binary_digits[6] = decimal[1] ? 8'h31 : 8'h30;
  assign binary_digits[7] = decimal[0] ? 8'h31 : 8'h30;

  // Construct the output string
  assign binary_str[7:0] = char0;
  assign binary_str[15:8] = char1;
  assign binary_str[23:16] = binary_digits[0];
  assign binary_str[31:24] = binary_digits[1];
  assign binary_str[39:32] = binary_digits[2];
  assign binary_str[47:40] = binary_digits[3];
  assign binary_str[55:48] = binary_digits[4];
  assign binary_str[63:56] = binary_digits[5];
  assign binary_str[71:64] = char9;

endmodule