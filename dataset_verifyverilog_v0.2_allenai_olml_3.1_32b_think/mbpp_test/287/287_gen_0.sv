module sum_even_squares(input [7:0] n, output [31:0] result);
wire [31:0] temp1, temp2, temp3, temp_n_plus_1, temp_2n_plus_1;
assign temp1 = 2 * (32'd n);
assign temp_n_plus_1 = (32'd n) + 1;
assign temp_2n_plus_1 = temp1 + 1;
assign temp2 = temp1 * temp_n_plus_1;
assign temp3 = temp2 * temp_2n_plus_1;
assign result = temp3 / 3;
endmodule