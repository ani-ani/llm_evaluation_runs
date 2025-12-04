module pos_counter(input signed [3:0][3:0] numbers, output [2:0] pos_count);
  assign pos_count = (numbers[0][3] == 1'b0) + (numbers[1][3] == 1'b0) + (numbers[2][3] == 1'b0) + (numbers[3][3] == 1'b0);
endmodule