module check_month_31_days (
  input [3:0] month,
  output has_31_days
);

  assign has_31_days = (month == 4'd1) || (month == 4'd3) || (month == 4'd5) || (month == 4'd7) || (month == 4'd8) || (month == 4'd10) || (month == 4'd12);

endmodule