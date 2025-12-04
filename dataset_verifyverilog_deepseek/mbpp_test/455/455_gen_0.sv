module month_check (
  input [3:0] monthnum,
  output logic has_31_days
);

  assign has_31_days = (monthnum == 4'd1) | (monthnum == 4'd3) | 
                      (monthnum == 4'd5) | (monthnum == 4'd7) | 
                      (monthnum == 4'd8) | (monthnum == 4'd10) | 
                      (monthnum == 4'd12);

endmodule