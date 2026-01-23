module filter_integers(input [15:0][23:0] data_array, output [7:0] count, output [15:0][15:0] filtered_integers);
assign count = (data_array[0][7:0] == 8'h00) ? 1 :0 + (data_array[1][7:0] == 8'h00) ? 1 :0 + (data_array[2][7:0] == 8'h00) ? 1 :0 + (data_array[3][7:0] == 8'h00) ? 1 :0 + (data_array[4][7:0] == 8'h00) ? 1 :0 + (data_array[5][7:0] == 8'h00) ? 1 :0 + (data_array[6][7:0] == 8'h00) ? 1 :0 + (data_array[7][7:0] == 8'h00) ? 1 :0 + (data_array[8][7:0] == 8'h00) ? 1 :0 + (data_array[9][7:0] == 8'h00) ? 1 :0 + (data_array[10][7:0] == 8'h00) ? 1 :0 + (data_array[11][7:0] == 8'h00) ? 1 :0 + (data_array[12][7:0] == 8'h00) ? 1 :0 + (data_array[13][7:0] == 8'h00) ? 1 :0 + (data_array[14][7:0] == 8'h00) ? 1 :0 + (data_array[15][7:0] == 8'h00) ? 1 :0 ;
assign filtered_integers[0] = (data_array[0][7:0] == 8'h00) ? data_array[0][23:8] : 16'b0;
assign filtered_integers[1] = (data_array[1][7:0] == 8'h00) ? data_array[1][23:8] : 16'b0;
assign filtered_integers[2] = (data_array[2][7:0] == 8'h00) ? data_array[2][23:8] : 16'b0;
assign filtered_integers[3] = (data_array[3][7:0] == 8'h00) ? data_array[3][23:8] : 16'b0;
assign filtered_integers[4] = (data_array[4][7:0] == 8'h00) ? data_array[4][23:8] : 16'b0;
assign filtered_integers[5] = (data_array[5][7:0] == 8'h00) ? data_array[5][23:8] : 16'b0;
assign filtered_integers[6] = (data_array[6][7:0] == 8'h00) ? data_array[6][23:8] : 16'b0;
assign filtered_integers[7] = (data_array[7][7:0] == 8'h00) ? data_array[7][23:8] : 16'b0;
assign filtered_integers[8] = (data_array[8][7:0] == 8'h00) ? data_array[8][23:8] : 16'b0;
assign filtered_integers[9] = (data_array[9][7:0] == 8'h00) ? data_array[9][23:8] : 16'b0;
assign filtered_integers[10] = (data_array[10][7:0] == 8'h00) ? data_array[10][23:8] : 16'b0;
assign filtered_integers[11] = (data_array[11][7:0] == 8'h00) ? data_array[11][23:8] : 16'b0;
assign filtered_integers[12] = (data_array[12][7:0] == 8'h00) ? data_array[12][23:8] : 16'b0;
assign filtered_integers[13] = (data_array[13][7:0] == 8'h00) ? data_array[13][23:8] : 16'b0;
assign filtered_integers[14] = (data_array[14][7:0] == 8'h00) ? data_array[14][23:8] : 16'b0;
assign filtered_integers[15] = (data_array[15][7:0] == 8'h00) ? data_array[15][23:8] : 16'b0;
endmodule