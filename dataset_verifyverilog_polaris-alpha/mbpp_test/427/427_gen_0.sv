module date_format_converter(
  input  [11:0] year,
  input  [3:0]  month,
  input  [4:0]  day,
  output [20:0] formatted_date
);

  assign formatted_date = {day, month, year};

endmodule