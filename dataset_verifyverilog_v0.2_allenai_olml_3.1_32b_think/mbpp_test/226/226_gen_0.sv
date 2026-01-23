module odd_index_filter(input [7:0] char_array [0:15], input [3:0] length, output [7:0] result [0:7], output [3:0] result_length);
assign result_length = (length + 1) / 2;
assign result[0] = (result_length > 0) ? char_array[0] : 8'h00;
assign result[1] = (result_length > 1) ? char_array[2] : 8'h00;
assign result[2] = (result_length > 2) ? char_array[4] : 8'h00;
assign result[3] = (result_length > 3) ? char_array[6] : 8'h00;
assign result[4] = (result_length > 4) ? char_array[8] : 8'h00;
assign result[5] = (result_length > 5) ? char_array[10] : 8'h00;
assign result[6] = (result_length > 6) ? char_array[12] : 8'h00;
assign result[7] = (result_length > 7) ? char_array[14] : 8'h00;
endmodule