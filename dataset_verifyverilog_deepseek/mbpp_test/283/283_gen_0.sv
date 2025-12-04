module digit_frequency_check(
  input reg [15:0] num,
  output valid
);

  logic [2:0] count_0, count_1, count_2, count_3;
  
  assign count_0 = (num[15:12] == 4'd0) + (num[11:8] == 4'd0) + (num[7:4] == 4'd0) + (num[3:0] == 4'd0);
  assign count_1 = (num[15:12] == 4'd1) + (num[11:8] == 4'd1) + (num[7:4] == 4'd1) + (num[3:0] == 4'd1);
  assign count_2 = (num[15:12] == 4'd2) + (num[11:8] == 4'd2) + (num[7:4] == 4'd2) + (num[3:0] == 4'd2);
  assign count_3 = (num[15:12] == 4'd3) + (num[11:8] == 4'd3) + (num[7:4] == 4'd3) + (num[3:0] == 4'd3);
  
  logic valid0, valid1, valid2, valid3;
  assign valid0 = (count_0 == 3'd0);
  assign valid1 = (count_1 <= 3'd1);
  assign valid2 = (count_2 <= 3'd2);
  assign valid3 = (count_3 <= 3'd3);
  
  assign valid = valid0 & valid1 & valid2 & valid3;

endmodule