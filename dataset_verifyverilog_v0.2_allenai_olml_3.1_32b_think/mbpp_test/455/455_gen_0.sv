module check_month_31_days(input [3:0] month, output has_31_days);
  assign has_31_days = (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12);
endmodule