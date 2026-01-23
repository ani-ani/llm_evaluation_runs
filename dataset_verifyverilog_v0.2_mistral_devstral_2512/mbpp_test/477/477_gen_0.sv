module string_to_lower (
  input [7:0] char_0,
  input [7:0] char_1,
  input [7:0] char_2,
  input [7:0] char_3,
  input [7:0] char_4,
  input [7:0] char_5,
  input [7:0] char_6,
  input [7:0] char_7,
  output [7:0] lower_char_0,
  output [7:0] lower_char_1,
  output [7:0] lower_char_2,
  output [7:0] lower_char_3,
  output [7:0] lower_char_4,
  output [7:0] lower_char_5,
  output [7:0] lower_char_6,
  output [7:0] lower_char_7
);

  assign lower_char_0 = (char_0 >= 8'h41 && char_0 <= 8'h5A) ? char_0 + 8'h20 : char_0;
  assign lower_char_1 = (char_1 >= 8'h41 && char_1 <= 8'h5A) ? char_1 + 8'h20 : char_1;
  assign lower_char_2 = (char_2 >= 8'h41 && char_2 <= 8'h5A) ? char_2 + 8'h20 : char_2;
  assign lower_char_3 = (char_3 >= 8'h41 && char_3 <= 8'h5A) ? char_3 + 8'h20 : char_3;
  assign lower_char_4 = (char_4 >= 8'h41 && char_4 <= 8'h5A) ? char_4 + 8'h20 : char_4;
  assign lower_char_5 = (char_5 >= 8'h41 && char_5 <= 8'h5A) ? char_5 + 8'h20 : char_5;
  assign lower_char_6 = (char_6 >= 8'h41 && char_6 <= 8'h5A) ? char_6 + 8'h20 : char_6;
  assign lower_char_7 = (char_7 >= 8'h41 && char_7 <= 8'h5A) ? char_7 + 8'h20 : char_7;

endmodule