module month_30days_check(
  input [3:0] month_num,
  output logic is_30days
);

  always_comb begin
    case (month_num)
      4, 6, 9, 11: is_30days = 1'b1;
      default: is_30days = 1'b0;
    endcase
  end

endmodule