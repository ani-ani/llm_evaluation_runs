module date_format_converter (
  input  wire [11:0] year,   // Year value (0-4095)
  input  wire [3:0] month,   // Month (1-12)
  input  wire [4:0] day,     // Day (1-31)
  output wire  [20:0] formatted_date // Concatenated as {day[4:0],month[3:0],year[11:0]}
);
  // Concatenation in day-month-year order
  assign formatted_date = {day[4:0], month[3:0], year[11:0]};
endmodule
