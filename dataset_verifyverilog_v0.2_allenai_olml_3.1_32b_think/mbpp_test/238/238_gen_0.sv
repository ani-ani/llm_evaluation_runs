module substring_counter (
input [7:0] char_0,
input [7:0] char_1,
input [7:0] char_2,
input [7:0] char_3,
input [7:0] char_4,
input [7:0] char_5,
input [7:0] char_6,
input [7:0] char_7,
output [7:0] result
);
assign first_zero_pos = (char_0 == 0) ? 0 : (char_1 == 0) ? 1 : (char_2 == 0) ? 2 : (char_3 == 0) ? 3 : (char_4 == 0) ? 4 : (char_5 == 0) ? 5 : (char_6 == 0) ? 6 : (char_7 == 0) ? 7 : 8;
assign n = first_zero_pos;
assign result = (n * (n + 1)) >> 1;
endmodule