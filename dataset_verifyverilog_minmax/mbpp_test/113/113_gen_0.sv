module integer_checker (
  input [7:0] str [0:7], // 8 ASCII characters
  input [3:0] length,    // String length (0-8)
  output logic is_integer // High if valid integer format
);

  // Single-cycle combinational logic
  // 1) Output LOW for length=0
  // 2) First char: '+' (0x2B), '-' (0x2D), or digit ('0'-'9')
  // 3) Remaining chars: digits only if length>1
  logic [7:0] first;
  logic first_is_sign, first_is_digit, first_ok;
  logic [7:0] i1_char, i2_char, i3_char, i4_char, i5_char, i6_char, i7_char;
  logic i1_digit, i2_digit, i3_digit, i4_digit, i5_digit, i6_digit, i7_digit;

  assign first = str[0];
  assign first_is_sign  = (first == 8'h2B) || (first == 8'h2D); // '+' or '-'
  assign first_is_digit = (first >= 8'h30) && (first <= 8'h39); // '0'..'9'
  assign first_ok       = first_is_sign || first_is_digit;

  // Remaining characters (valid only if length > 1)
  assign i1_char = str[1];
  assign i2_char = str[2];
  assign i3_char = str[3];
  assign i4_char = str[4];
  assign i5_char = str[5];
  assign i6_char = str[6];
  assign i7_char = str[7];

  assign i1_digit = (i1_char >= 8'h30) && (i1_char <= 8'h39);
  assign i2_digit = (i2_char >= 8'h30) && (i2_char <= 8'h39);
  assign i3_digit = (i3_char >= 8'h30) && (i3_char <= 8'h39);
  assign i4_digit = (i4_char >= 8'h30) && (i4_char <= 8'h39);
  assign i5_digit = (i5_char >= 8'h30) && (i5_char <= 8'h39);
  assign i6_digit = (i6_char >= 8'h30) && (i6_char <= 8'h39);
  assign i7_digit = (i7_char >= 8'h30) && (i7_char <= 8'h39);

  logic length_gt_1;
  assign length_gt_1 = (length > 4'd1);

  logic rest_ok;
  assign rest_ok =
    (!length_gt_1) ||
    ( (length == 4'd2) ? i1_digit :
      (length == 4'd3) ? (i1_digit && i2_digit) :
      (length == 4'd4) ? (i1_digit && i2_digit && i3_digit) :
      (length == 4'd5) ? (i1_digit && i2_digit && i3_digit && i4_digit) :
      (length == 4'd6) ? (i1_digit && i2_digit && i3_digit && i4_digit && i5_digit) :
      (length == 4'd7) ? (i1_digit && i2_digit && i3_digit && i4_digit && i5_digit && i6_digit) :
      (i1_digit && i2_digit && i3_digit && i4_digit && i5_digit && i6_digit && i7_digit) );

  assign is_integer = (length != 4'd0) && first_ok && rest_ok;

endmodule