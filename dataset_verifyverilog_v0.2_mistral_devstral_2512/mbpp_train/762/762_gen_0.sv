module month_30days_check(
  input [4:0] month,
  output is_30_days
);
  assign is_30_days = (month == 5'd4) || (month == 5'd6) || (month == 5'd9) || (month == 5'd11);
endmodule