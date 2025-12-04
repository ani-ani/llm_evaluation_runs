module clock_corrector(
  input [3:0] hour_tens, // 1st digit of hour (0-2 for 24hr)
  input [3:0] hour_units, // 2nd digit of hour (0-9)
  input [3:0] min_tens,   // 1st digit of minutes (0-5)
  input [3:0] min_units,  // 2nd digit of minutes (0-9)
  input is_24h_format,    // 1=24-hour clock, 0=12-hour
  output [3:0] corr_hour_tens,
  output [3:0] corr_hour_units,
  output [3:0] corr_min_tens,
  output [3:0] corr_min_units
);

  // Minutes correction
  wire [3:0] min_units_clamp;
  assign min_units_clamp = (min_units > 4'd9) ? 4'd0 : min_units;

  wire [3:0] min_tens_corr;
  assign min_tens_corr = (min_tens > 4'd5) ? 4'd5 : min_tens;

  wire [3:0] min_units_corr;
  assign min_units_corr = (min_units > 4'd9)
                          ? ((min_tens_corr == 4'd5) ? 4'd0 : min_units)
                          : min_units_clamp;

  // Internal corrected minutes
  wire [3:0] corr_min_tens_int = min_tens_corr;
  wire [3:0] corr_min_units_int = min_units_corr;

  // Hour correction (24h)
  wire [3:0] hour_units_clamp;
  assign hour_units_clamp = (hour_units > 4'd9) ? 4'd0 : hour_units;

  wire [3:0] hour_tens_24_corr;
  assign hour_tens_24_corr = (hour_tens > 4'd2)
                             ? ((hour_units_clamp > 4'd3) ? 4'd0 : 4'd1)
                             : hour_tens;

  wire [3:0] hour_units_24_corr;
  assign hour_units_24_corr = (hour_tens > 4'd2)
                               ? hour_units_clamp
                               : ((hour_tens == 4'd2 && hour_units_clamp > 4'd3)
                                   ? hour_units_clamp
                                   : ((hour_tens == 4'd2 && hour_units > 4'd9) ? 4'd0 : hour_units_clamp));

  // Hour correction (12h)
  wire [3:0] hour_units_12_corr;
  assign hour_units_12_corr = hour_units_clamp;

  wire [3:0] hour_tens_12_corr;
  wire is_hour_zero;
  assign is_hour_zero = (hour_tens == 4'd0 && hour_units_12_corr == 4'd0);
  assign hour_tens_12_corr = (hour_tens > 4'd1)
                             ? 4'd1
                             : (is_hour_zero ? 4'd0 : hour_tens);

  // Outputs
  assign corr_min_tens  = corr_min_tens_int;
  assign corr_min_units = corr_min_units_int;

  assign corr_hour_tens  = is_24h_format ? hour_tens_24_corr : hour_tens_12_corr;
  assign corr_hour_units = is_24h_format ? hour_units_24_corr : hour_units_12_corr;

endmodule