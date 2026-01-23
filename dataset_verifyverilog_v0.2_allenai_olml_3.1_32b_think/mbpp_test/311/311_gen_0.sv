module set_left_most_unset_bit (
input [15:0] n,
output [15:0] result
);
wire [15:0] higher_and;
assign higher_and[15] = 1'b1;
assign higher_and[14] = n[15] & higher_and[15];
assign higher_and[13] = n[14] & higher_and[14];
assign higher_and[12] = n[13] & higher_and[13];
assign higher_and[11] = n[12] & higher_and[12];
assign higher_and[10] = n[11] & higher_and[11];
assign higher_and[9] = n[10] & higher_and[10];
assign higher_and[8] = n[9] & higher_and[9];
assign higher_and[7] = n[8] & higher_and[8];
assign higher_and[6] = n[7] & higher_and[7];
assign higher_and[5] = n[6] & higher_and[6];
assign higher_and[4] = n[5] & higher_and[5];
assign higher_and[3] = n[4] & higher_and[4];
assign higher_and[2] = n[3] & higher_and[3];
assign higher_and[1] = n[2] & higher_and[2];
assign higher_and[0] = n[1] & higher_and[1];
wire [15:0] is_first_zero;
assign is_first_zero[15] = !n[15];
assign is_first_zero[14] = (!n[14]) & higher_and[14];
assign is_first_zero[13] = (!n[13]) & higher_and[13];
assign is_first_zero[12] = (!n[12]) & higher_and[12];
assign is_first_zero[11] = (!n[11]) & higher_and[11];
assign is_first_zero[10] = (!n[10]) & higher_and[10];
assign is_first_zero[9] = (!n[9]) & higher_and[9];
assign is_first_zero[8] = (!n[8]) & higher_and[8];
assign is_first_zero[7] = (!n[7]) & higher_and[7];
assign is_first_zero[6] = (!n[6]) & higher_and[6];
assign is_first_zero[5] = (!n[5]) & higher_and[5];
assign is_first_zero[4] = (!n[4]) & higher_and[4];
assign is_first_zero[3] = (!n[3]) & higher_and[3];
assign is_first_zero[2] = (!n[2]) & higher_and[2];
assign is_first_zero[1] = (!n[1]) & higher_and[1];
assign is_first_zero[0] = (!n[0]) & higher_and[0];
wire [15:0] mask;
assign mask = is_first_zero[15] <<15 | is_first_zero[14] <<14 | is_first_zero[13] <<13 | is_first_zero[12] <<12 | is_first_zero[11] <<11 | is_first_zero[10] <<10 | is_first_zero[9] <<9 | is_first_zero[8] <<8 | is_first_zero[7] <<7 | is_first_zero[6] <<6 | is_first_zero[5] <<5 | is_first_zero[4] <<4 | is_first_zero[3] <<3 | is_first_zero[2] <<2 | is_first_zero[1] <<1 | is_first_zero[0];
assign result = n | mask;
endmodule