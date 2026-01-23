module count_integers(input [7:0] data [0:7], output [3:0] count);
assign count = (data[0][7:4] == 4'b0001) + (data[1][7:4] == 4'b0001) + (data[2][7:4] == 4'b0001) + (data[3][7:4] == 4'b0001) + (data[4][7:4] == 4'b0001) + (data[5][7:4] == 4'b0001) + (data[6][7:4] == 4'b0001) + (data[7][7:4] == 4'b0001);
endmodule