module integer_checker(
  input  [7:0] str [0:7],
  input  [3:0] length,
  output       is_integer
);

  // Internal wires for checks
  wire len_nonzero;
  wire first_is_sign;
  wire first_is_digit;
  wire first_valid;
  wire rest_digits_ok;

  assign len_nonzero   = (length != 4'd0);
  assign first_is_sign = (str[0] == 8'h2B) || (str[0] == 8'h2D);
  assign first_is_digit = (str[0] >= 8'h30) && (str[0] <= 8'h39);
  assign first_valid   = len_nonzero && (first_is_sign || first_is_digit);

  // Check remaining characters (from index 1 up to length-1) are digits
  wire c1_ok = (length <= 4'd1) || ((str[1] >= 8'h30) && (str[1] <= 8'h39));
  wire c2_ok = (length <= 4'd2) || ((str[2] >= 8'h30) && (str[2] <= 8'h39));
  wire c3_ok = (length <= 4'd3) || ((str[3] >= 8'h30) && (str[3] <= 8'h39));
  wire c4_ok = (length <= 4'd4) || ((str[4] >= 8'h30) && (str[4] <= 8'h39));
  wire c5_ok = (length <= 4'd5) || ((str[5] >= 8'h30) && (str[5] <= 8'h39));
  wire c6_ok = (length <= 4'd6) || ((str[6] >= 8'h30) && (str[6] <= 8'h39));
  wire c7_ok = (length <= 4'd7) || ((str[7] >= 8'h30) && (str[7] <= 8'h39));

  assign rest_digits_ok = c1_ok & c2_ok & c3_ok & c4_ok & c5_ok & c6_ok & c7_ok;

  assign is_integer = first_valid & rest_digits_ok;

endmodule