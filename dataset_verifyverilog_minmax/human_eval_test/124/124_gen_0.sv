module date_validator (
    input reg [79:0] date_str,
    output logic valid
  );

  // Internal signals
  logic hyphen_ok;
  logic [7:0] month_tens, month_units, month;
  logic [7:0] day_tens, day_units, day;
  logic month_valid;
  logic [7:0] max_day;
  logic day_valid;

  always_comb begin
    // Check hyphens at positions 2 and 5 (bytes 2 and 5)
    hyphen_ok = (date_str[23:16] == 8'h2D) && (date_str[47:40] == 8'h2D);

    // Convert month (bytes 0 and 1) from ASCII to decimal
    month_tens = date_str[7:0]   - 8'h30; // tens digit of month
    month_units = date_str[15:8] - 8'h30; // units digit of month
    month = (month_tens * 4'd10) + month_units;

    // Convert day (bytes 3 and 4) from ASCII to decimal
    day_tens = date_str[31:24] - 8'h30; // tens digit of day
    day_units = date_str[39:32] - 8'h30; // units digit of day
    day = (day_tens * 4'd10) + day_units;

    // Month must be between 1 and 12
    month_valid = (month >= 1) && (month <= 12);

    // Determine maximum day for the month
    case (month)
      1, 3, 5, 7, 8, 10, 12: max_day = 8'd31;
      4, 6, 9, 11            : max_day = 8'd30;
      2                       : max_day = 8'd29;
      default                 : max_day = 8'd0;
    endcase

    // Day must be between 1 and max_day
    day_valid = (day >= 1) && (day <= max_day);

    // Overall validity
    valid = hyphen_ok && month_valid && day_valid;
  end
endmodule