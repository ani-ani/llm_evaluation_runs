module file_name_check(input [127:0] file_name, output reg is_valid);
  // Extract characters (big-endian assumption)
  assign char_0 = file_name >> 120 & 0xFF;
  assign char_1 = file_name >> 112 & 0xFF;
  assign char_2 = file_name >> 104 & 0xFF;
  assign char_3 = file_name >> 96 & 0xFF;
  assign char_4 = file_name >> 88 & 0xFF;
  assign char_5 = file_name >> 80 & 0xFF;
  assign char_6 = file_name >> 72 & 0xFF;
  assign char_7 = file_name >> 64 & 0xFF;
  assign char_8 = file_name >> 56 & 0xFF;
  assign char_9 = file_name >> 48 & 0xFF;
  assign char_10 = file_name >> 40 & 0xFF;
  assign char_11 = file_name >> 32 & 0xFF;
  assign char_12 = file_name >> 24 & 0xFF;
  assign char_13 = file_name >> 16 & 0xFF;
  assign char_14 = file_name >> 8 & 0xFF;
  assign char_15 = file_name >> 0 & 0xFF;

  // Calculate digit count
  assign digit_count =
    (char_0 >= '0' && char_0 <= '9') ? 1 : 0 +
    (char_1 >= '0' && char_1 <= '9') ? 1 : 0 +
    (char_2 >= '0' && char_2 <= '9') ? 1 : 0 +
    (char_3 >= '0' && char_3 <= '9') ? 1 : 0 +
    (char_4 >= '0' && char_4 <= '9') ? 1 : 0 +
    (char_5 >= '0' && char_5 <= '9') ? 1 : 0 +
    (char_6 >= '0' && char_6 <= '9') ? 1 : 0 +
    (char_7 >= '0' && char_7 <= '9') ? 1 : 0 +
    (char_8 >= '0' && char_8 <= '9') ? 1 : 0 +
    (char_9 >= '0' && char_9 <= '9') ? 1 : 0 +
    (char_10 >= '0' && char_10 <= '9') ? 1 : 0 +
    (char_11 >= '0' && char_11 <= '9') ? 1 : 0 +
    (char_12 >= '0' && char_12 <= '9') ? 1 : 0 +
    (char_13 >= '0' && char_13 <= '9') ? 1 : 0 +
    (char_14 >= '0' && char_14 <= '9') ? 1 : 0 +
    (char_15 >= '0' && char_15 <= '9') ? 1 : 0;

  // Calculate dot count and position
  assign dot_count =
    (char_0 == '.') ? 1 : 0 +
    (char_1 == '.') ? 1 : 0 +
    (char_2 == '.') ? 1 : 0 +
    (char_3 == '.') ? 1 : 0 +
    (char_4 == '.') ? 1 : 0 +
    (char_5 == '.') ? 1 : 0 +
    (char_6 == '.') ? 1 : 0 +
    (char_7 == '.') ? 1 : 0 +
    (char_8 == '.') ? 1 : 0 +
    (char_9 == '.') ? 1 : 0 +
    (char_10 == '.') ? 1 : 0 +
    (char_11 == '.') ? 1 : 0 +
    (char_12 == '.') ? 1 : 0 +
    (char_13 == '.') ? 1 : 0 +
    (char_14 == '.') ? 1 : 0 +
    (char_15 == '.') ? 1 : 0;

  assign dot_pos = (char_0 == '.') ? 0 :
    (char_1 == '.') ? 1 :
    (char_2 == '.') ? 2 :
    (char_3 == '.') ? 3 :
    (char_4 == '.') ? 4 :
    (char_5 == '.') ? 5 :
    (char_6 == '.') ? 6 :
    (char_7 == '.') ? 7 :
    (char_8 == '.') ? 8 :
    (char_9 == '.') ? 9 :
    (char_10 == '.') ? 10 :
    (char_11 == '.') ? 11 :
    (char_12 == '.') ? 12 :
    (char_13 == '.') ? 13 :
    (char_14 == '.') ? 14 :
    (char_15 == '.') ? 15 :
    16'd16;

  // Check character before dot is a letter
  assign char_before_dot = (dot_pos == 1) ? char_0 :
    (dot_pos == 2) ? char_1 :
    (dot_pos == 3) ? char_2 :
    (dot_pos == 4) ? char_3 :
    (dot_pos == 5) ? char_4 :
    (dot_pos == 6) ? char_5 :
    (dot_pos == 7) ? char_6 :
    (dot_pos == 8) ? char_7 :
    (dot_pos == 9) ? char_8 :
    (dot_pos == 10) ? char_9 :
    (dot_pos == 11) ? char_10 :
    (dot_pos == 12) ? char_11 :
    (dot_pos == 13) ? char_12 :
    (dot_pos == 14) ? char_13 :
    (dot_pos == 15) ? char_14 : 0;

  assign is_letter = (char_before_dot >= 'a' && char_before_dot <= 'z') ? 1 : 0;
  is_letter |= (char_before_dot >= 'A' && char_before_dot <= 'Z') ? 1 : 0;

  // Check suffix
  assign valid_dot_pos = (dot_pos + 3 < 16);

  assign char_dot1 = (dot_pos == 0) ? char_1 :
    (dot_pos == 1) ? char_2 :
    (dot_pos == 2) ? char_3 :
    (dot_pos == 3) ? char_4 :
    (dot_pos == 4) ? char_5 :
    (dot_pos == 5) ? char_6 :
    (dot_pos == 6) ? char_7 :
    (dot_pos == 7) ? char_8 :
    (dot_pos == 8) ? char_9 :
    (dot_pos == 9) ? char_10 :
    (dot_pos == 10) ? char_11 :
    (dot_pos == 11) ? char_12 :
    (dot_pos == 12) ? char_13 :
    (dot_pos == 13) ? char_14 :
    (dot_pos == 14) ? char_15 : 0;

  assign char_dot2 = (dot_pos == 0) ? char_2 :
    (dot_pos == 1) ? char_3 :
    (dot_pos == 2) ? char_4 :
    (dot_pos == 3) ? char_5 :
    (dot_pos == 4) ? char_6 :
    (dot_pos == 5) ? char_7 :
    (dot_pos == 6) ? char_8 :
    (dot_pos == 7) ? char_9 :
    (dot_pos == 8) ? char_10 :
    (dot_pos == 9) ? char_11 :
    (dot_pos == 10) ? char_12 :
    (dot_pos == 11) ? char_13 :
    (dot_pos == 12) ? char_14 :
    (dot_pos == 13) ? char_15 : 0;

  assign char_dot3 = (dot_pos == 0) ? char_3 :
    (dot_pos == 1) ? char_4 :
    (dot_pos == 2) ? char_5 :
    (dot_pos == 3) ? char_6 :
    (dot_pos == 4) ? char_7 :
    (dot_pos == 5) ? char_8 :
    (dot_pos == 6) ? char_9 :
    (dot_pos == 7) ? char_10 :
    (dot_pos == 8) ? char_11 :
    (dot_pos == 9) ? char_12 :
    (dot_pos == 10) ? char_13 :
    (dot_pos == 11) ? char_14 :
    (dot_pos == 12) ? char_15 : 0;

  assign suffix_match_txt = (char_dot1 == 't') && (char_dot2 == 'x') && (char_dot3 == 't');
  assign suffix_match_exe = (char_dot1 == 'e') && (char_dot2 == 'x') && (char_dot3 == 'e');
  assign suffix_match_dll = (char_dot1 == 'd') && (char_dot2 == 'l') && (char_dot3 == 'l');
  assign suffix_valid = suffix_match_txt || suffix_match_exe || suffix_match_dll;

  assign cond1 = (digit_count <= 3);
  assign cond2 = (dot_count == 1);
  assign cond3 = (dot_pos > 0);
  assign cond4 = is_letter;
  assign cond5 = valid_dot_pos && suffix_valid;

  assign is_valid = cond1 && cond2 && cond3 && cond4 && cond5;
endmodule