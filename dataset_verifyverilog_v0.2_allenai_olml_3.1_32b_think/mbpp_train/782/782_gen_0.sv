module odd_length_sum (
input [7:0] arr_0,
input [7:0] arr_1,
input [7:0] arr_2,
input [7:0] arr_3,
input [7:0] arr_4,
input [7:0] arr_5,
input [7:0] arr_6,
input [7:0] arr_7,
input [2:0] length,
output [31:0] result
);
wire [3:0] length_ext;
assign length_ext = {1'b0, length};
assign result = 
(arr_0 * ( (length_ext + 1) / 2 ) * 1 ) + 
(arr_1 * ( ( 2 * (length_ext - 1) + 1 ) / 2 ) * (length[1] | length[2]) ) + 
(arr_2 * ( ( 3 * (length_ext - 2) + 1 ) / 2 ) * (length[2] | (length[1] & length[0]) ) ) + 
(arr_3 * ( ( 4 * (length_ext - 3) + 1 ) / 2 ) * length[2] ) + 
(arr_4 * ( ( 5 * (length_ext - 4) + 1 ) / 2 ) * (length[2] & (length[1] | length[0]) ) ) + 
(arr_5 * ( ( 6 * (length_ext - 5) + 1 ) / 2 ) * (length[2] & length[1]) ) + 
(arr_6 * ( ( 7 * (length_ext - 6) + 1 ) / 2 ) * (length[2] & length[1] & length[0]) ) + 
(arr_7 * ( ( 8 * (length_ext - 7) + 1 ) / 2 ) * 0 );
endmodule