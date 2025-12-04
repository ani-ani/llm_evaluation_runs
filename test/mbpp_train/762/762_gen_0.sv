module month_30days_check(
  input  [3:0] month_num,
  output       is_30days
);

  assign is_30days = (month_num == 4'd4)  ||
                     (month_num == 4'd6)  ||
                     (month_num == 4'd9)  ||
                     (month_num == 4'd11);

endmodule