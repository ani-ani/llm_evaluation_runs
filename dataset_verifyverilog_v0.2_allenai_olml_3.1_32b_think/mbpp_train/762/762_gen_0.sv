module month_30days_check(input [4:0] month, output is_30_days);
  assign is_30_days = (month ==4) || (month ==6) || (month ==9) || (month ==11);
endmodule