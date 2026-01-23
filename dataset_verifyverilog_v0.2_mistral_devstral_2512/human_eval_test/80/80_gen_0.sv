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

  wire window_0_valid = (length >= 3);
  wire window_1_valid = (length >= 4);
  wire window_2_valid = (length >= 5);
  wire window_3_valid = (length >= 6);
  wire window_4_valid = (length >= 7);
  wire window_5_valid = (length >= 8);

  wire window_0_distinct = (char_0 != char_1) && (char_0 != char_2) && (char_1 != char_2);
  wire window_1_distinct = (char_1 != char_2) && (char_1 != char_3) && (char_2 != char_3);
  wire window_2_distinct = (char_2 != char_3) && (char_2 != char_4) && (char_3 != char_4);
  wire window_3_distinct = (char_3 != char_4) && (char_3 != char_5) && (char_4 != char_5);
  wire window_4_distinct = (char_4 != char_5) && (char_4 != char_6) && (char_5 != char_6);
  wire window_5_distinct = (char_5 != char_6) && (char_5 != char_7) && (char_6 != char_7);

  wire all_windows_valid = 
    (!window_0_valid || window_0_distinct) &&
    (!window_1_valid || window_1_distinct) &&
    (!window_2_valid || window_2_distinct) &&
    (!window_3_valid || window_3_distinct) &&
    (!window_4_valid || window_4_distinct) &&
    (!window_5_valid || window_5_distinct);

  assign is_happy = (length >= 3) && all_windows_valid;

endmodule