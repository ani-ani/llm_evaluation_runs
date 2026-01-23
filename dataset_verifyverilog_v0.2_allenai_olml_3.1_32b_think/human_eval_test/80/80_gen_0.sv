module is_happy (
    input [7:0] char_0,
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    input [2:0] length,
    output is_happy
);

assign window_valid_0 = (length > 2);
assign window_valid_1 = (length > 3);
assign window_valid_2 = (length > 4);
assign window_valid_3 = (length > 5);
assign window_valid_4 = (length > 6);
assign window_valid_5 = (length > 7);

assign valid_0 = (char_0 != char_1) && (char_0 != char_2) && (char_1 != char_2);
assign valid_1 = (char_1 != char_2) && (char_1 != char_3) && (char_2 != char_3);
assign valid_2 = (char_2 != char_3) && (char_2 != char_4) && (char_3 != char_4);
assign valid_3 = (char_3 != char_4) && (char_3 != char_5) && (char_4 != char_5);
assign valid_4 = (char_4 != char_5) && (char_4 != char_6) && (char_5 != char_6);
assign valid_5 = (char_5 != char_6) && (char_5 != char_7) && (char_6 != char_7);

assign term_0 = window_valid_0 ? valid_0 : 1'b1;
assign term_1 = window_valid_1 ? valid_1 : 1'b1;
assign term_2 = window_valid_2 ? valid_2 : 1'b1;
assign term_3 = window_valid_3 ? valid_3 : 1'b1;
assign term_4 = window_valid_4 ? valid_4 : 1'b1;
assign term_5 = window_valid_5 ? valid_5 : 1'b1;

assign all_valid = term_0 & term_1 & term_2 & term_3 & term_4 & term_5;

assign is_happy = (length >= 3) ? all_valid : 1'b0;

endmodule