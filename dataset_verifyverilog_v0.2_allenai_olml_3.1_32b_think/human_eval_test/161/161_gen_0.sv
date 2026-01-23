module string_transform (input [7:0] char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7, output [7:0] out_0, out_1, out_2, out_3, out_4, out_5, out_6, out_7);
assign is_letter_0 = (char_0 >= 8'h41 && char_0 <= 8'h5A) || (char_0 >= 8'h61 && char_0 <= 8'h7A);
assign is_letter_1 = (char_1 >= 8'h41 && char_1 <= 8'h5A) || (char_1 >= 8'h61 && char_1 <= 8'h7A);
assign is_letter_2 = (char_2 >= 8'h41 && char_2 <= 8'h5A) || (char_2 >= 8'h61 && char_2 <= 8'h7A);
assign is_letter_3 = (char_3 >= 8'h41 && char_3 <= 8'h5A) || (char_3 >= 8'h61 && char_3 <= 8'h7A);
assign is_letter_4 = (char_4 >= 8'h41 && char_4 <= 8'h5A) || (char_4 >= 8'h61 && char_4 <= 8'h7A);
assign is_letter_5 = (char_5 >= 8'h41 && char_5 <= 8'h5A) || (char_5 >= 8'h61 && char_5 <= 8'h7A);
assign is_letter_6 = (char_6 >= 8'h41 && char_6 <= 8'h5A) || (char_6 >= 8'h61 && char_6 <= 8'h7A);
assign is_letter_7 = (char_7 >= 8'h41 && char_7 <= 8'h5A) || (char_7 >= 8'h61 && char_7 <= 8'h7A);
assign has_letter = is_letter_0 | is_letter_1 | is_letter_2 | is_letter_3 | is_letter_4 | is_letter_5 | is_letter_6 | is_letter_7;
assign out_0 = has_letter ? (is_letter_0 ? (char_0 ^ 8'h20) : char_0) : char_7;
assign out_1 = has_letter ? (is_letter_1 ? (char_1 ^ 8'h20) : char_1) : char_6;
assign out_2 = has_letter ? (is_letter_2 ? (char_2 ^ 8'h20) : char_2) : char_5;
assign out_3 = has_letter ? (is_letter_3 ? (char_3 ^ 8'h20) : char_3) : char_4;
assign out_4 = has_letter ? (is_letter_4 ? (char_4 ^ 8'h20) : char_4) : char_3;
assign out_5 = has_letter ? (is_letter_5 ? (char_5 ^ 8'h20) : char_5) : char_2;
assign out_6 = has_letter ? (is_letter_6 ? (char_6 ^ 8'h20) : char_6) : char_1;
assign out_7 = has_letter ? (is_letter_7 ? (char_7 ^ 8'h20) : char_7) : char_0;
endmodule