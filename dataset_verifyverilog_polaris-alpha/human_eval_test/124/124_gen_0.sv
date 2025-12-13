module date_validator (
  input  [79:0] date_str,
  output       valid
);

  // Extract ASCII characters (little-endian per 8-bit slice)
  wire [7:0] m1 = date_str[7:0];    // tens of month
  wire [7:0] m0 = date_str[15:8];   // ones of month
  wire [7:0] d1 = date_str[23:16];  // tens of day
  wire [7:0] d0 = date_str[31:24];  // ones of day

  // Format check: positions 2 and 5 must be '-'
  // position 2 -> bits [23:16], position 5 -> bits [47:40]
  wire fmt_ok = (date_str[23:16] == 8'h2D) && (date_str[47:40] == 8'h2D);

  // Check that month/day digits are ASCII '0' to '9'
  wire m1_is_digit = (m1 >= 8'd48) && (m1 <= 8'd57);
  wire m0_is_digit = (m0 >= 8'd48) && (m0 <= 8'd57);
  wire d1_is_digit = (d1 >= 8'd48) && (d1 <= 8'd57);
  wire d0_is_digit = (d0 >= 8'd48) && (d0 <= 8'd57);

  // Convert ASCII to numeric values
  wire [3:0] m1_val = m1 - 8'd48;
  wire [3:0] m0_val = m0 - 8'd48;
  wire [3:0] d1_val = d1 - 8'd48;
  wire [3:0] d0_val = d0 - 8'd48;

  wire [5:0] month = m1_val * 6'd10 + m0_val;  // max 99
  wire [5:0] day   = d1_val * 6'd10 + d0_val;  // max 99

  // Month range check: 1-12
  wire month_ok = (month >= 6'd1) && (month <= 6'd12);

  // Day range by month
  wire is_31 = (month == 6'd1)  || (month == 6'd3)  || (month == 6'd5)  ||
               (month == 6'd7)  || (month == 6'd8)  || (month == 6'd10) ||
               (month == 6'd12);

  wire is_30 = (month == 6'd4) || (month == 6'd6) ||
               (month == 6'd9) || (month == 6'd11);

  wire is_feb = (month == 6'd2);

  wire day_31_ok = is_31 && (day >= 6'd1) && (day <= 6'd31);
  wire day_30_ok = is_30 && (day >= 6'd1) && (day <= 6'd30);
  wire day_feb_ok = is_feb && (day >= 6'd1) && (day <= 6'd29);

  wire day_ok = day_31_ok || day_30_ok || day_feb_ok;

  assign valid = fmt_ok && m1_is_digit && m0_is_digit && d1_is_digit && d0_is_digit && month_ok && day_ok;

endmodule