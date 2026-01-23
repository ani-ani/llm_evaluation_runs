module array_overlap (input [7:0] array1 [0:7], input [7:0] array2 [0:7], output reg overlap);
wire temp0, temp1, temp2, temp3, temp4, temp5, temp6, temp7;
assign temp0 = (array1[0] == array2[0]) | (array1[0] == array2[1]) | (array1[0] == array2[2]) | (array1[0] == array2[3]) | (array1[0] == array2[4]) | (array1[0] == array2[5]) | (array1[0] == array2[6]) | (array1[0] == array2[7]);
assign temp1 = (array1[1] == array2[0]) | (array1[1] == array2[1]) | (array1[1] == array2[2]) | (array1[1] == array2[3]) | (array1[1] == array2[4]) | (array1[1] == array2[5]) | (array1[1] == array2[6]) | (array1[1] == array2[7]);
assign temp2 = (array1[2] == array2[0]) | (array1[2] == array2[1]) | (array1[2] == array2[2]) | (array1[2] == array2[3]) | (array1[2] == array2[4]) | (array1[2] == array2[5]) | (array1[2] == array2[6]) | (array1[2] == array2[7]);
assign temp3 = (array1[3] == array2[0]) | (array1[3] == array2[1]) | (array1[3] == array2[2]) | (array1[3] == array2[3]) | (array1[3] == array2[4]) | (array1[3] == array2[5]) | (array1[3] == array2[6]) | (array1[3] == array2[7]);
assign temp4 = (array1[4] == array2[0]) | (array1[4] == array2[1]) | (array1[4] == array2[2]) | (array1[4] == array2[3]) | (array1[4] == array2[4]) | (array1[4] == array2[5]) | (array1[4] == array2[6]) | (array1[4] == array2[7]);
assign temp5 = (array1[5] == array2[0]) | (array1[5] == array2[1]) | (array1[5] == array2[2]) | (array1[5] == array2[3]) | (array1[5] == array2[4]) | (array1[5] == array2[5]) | (array1[5] == array2[6]) | (array1[5] == array2[7]);
assign temp6 = (array1[6] == array2[0]) | (array1[6] == array2[1]) | (array1[6] == array2[2]) | (array1[6] == array2[3]) | (array1[6] == array2[4]) | (array1[6] == array2[5]) | (array1[6] == array2[6]) | (array1[6] == array2[7]);
assign temp7 = (array1[7] == array2[0]) | (array1[7] == array2[1]) | (array1[7] == array2[2]) | (array1[7] == array2[3]) | (array1[7] == array2[4]) | (array1[7] == array2[5]) | (array1[7] == array2[6]) | (array1[7] == array2[7]);
assign overlap = temp0 | temp1 | temp2 | temp3 | temp4 | temp5 | temp6 | temp7;
endmodule