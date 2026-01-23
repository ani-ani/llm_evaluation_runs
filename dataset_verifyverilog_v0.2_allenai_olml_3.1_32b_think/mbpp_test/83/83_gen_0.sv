module char_from_string (output [7:0] result_char, input [7:0] char_0, input [7:0] char_1, input [7:0] char_2, input [7:0] char_3, input [7:0] char_4, input [7:0] char_5, input [7:0] char_6, input [7:0] char_7, input [2:0] len);

wire [4:0] value_0, value_1, value_2, value_3, value_4, value_5, value_6, value_7;
wire [9:0] sum_val;
wire [3:0] count;
wire [5:0] mod_val;

assign value_0 = (len > 0) ? ( (char_0 >= 8'h61 && char_0 <= 8'h7a) ? (char_0 - 8'h61 + 1) : 0 ) : 0;
assign value_1 = (len > 1) ? ( (char_1 >= 8'h61 && char_1 <= 8'h7a) ? (char_1 - 8'h61 + 1) : 0 ) : 0;
assign value_2 = (len > 2) ? ( (char_2 >= 8'h61 && char_2 <= 8'h7a) ? (char_2 - 8'h61 + 1) : 0 ) : 0;
assign value_3 = (len > 3) ? ( (char_3 >= 8'h61 && char_3 <= 8'h7a) ? (char_3 - 8'h61 + 1) : 0 ) : 0;
assign value_4 = (len > 4) ? ( (char_4 >= 8'h61 && char_4 <= 8'h7a) ? (char_4 - 8'h61 + 1) : 0 ) : 0;
assign value_5 = (len > 5) ? ( (char_5 >= 8'h61 && char_5 <= 8'h7a) ? (char_5 - 8'h61 + 1) : 0 ) : 0;
assign value_6 = (len > 6) ? ( (char_6 >= 8'h61 && char_6 <= 8'h7a) ? (char_6 - 8'h61 + 1) : 0 ) : 0;
assign value_7 = (len > 7) ? ( (char_7 >= 8'h61 && char_7 <= 8'h7a) ? (char_7 - 8'h61 + 1) : 0 ) : 0;

assign sum_val = value_0 + value_1 + value_2 + value_3 + value_4 + value_5 + value_6 + value_7;

assign count = (sum_val >=26) + (sum_val >=52) + (sum_val >=78) + (sum_val >=104) + (sum_val >=130) + (sum_val >=156) + (sum_val >=182) + (sum_val >=208);

assign mod_val = sum_val - 26 * count;

assign result_char = (mod_val == 0) ? 8'h7a : (8'h61 + mod_val - 1);

endmodule