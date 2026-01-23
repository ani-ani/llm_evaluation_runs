module digit_sum(input [15:0] num, output [7:0] sum);
wire [15:0] num_0, num_1, num_2, num_3, num_4;
wire [3:0] digit_0, digit_1, digit_2, digit_3, digit_4;
assign num_0 = num;
assign digit_0 = num_0 % 10;
assign num_1 = num_0 / 10;
assign num_2 = num_1 / 10;
assign digit_1 = num_1 % 10;
assign num_3 = num_2 / 10;
assign digit_2 = num_2 % 10;
assign num_4 = num_3 / 10;
assign digit_3 = num_3 % 10;
assign digit_4 = num_4 % 10;
assign sum = digit_0 + digit_1 + digit_2 + digit_3 + digit_4;
endmodule