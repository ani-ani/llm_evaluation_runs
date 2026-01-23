module remove_lowercase (
  input [7:0] char0,
  input [7:0] char1,
  input [7:0] char2,
  input [7:0] char3,
  input [7:0] char4,
  input [7:0] char5,
  input [7:0] char6,
  input [7:0] char7,
  input [3:0] length,
  output [7:0] out0,
  output [7:0] out1,
  output [7:0] out2,
  output [7:0] out3,
  output [7:0] out4,
  output [7:0] out5,
  output [7:0] out6,
  output [7:0] out7,
  output [3:0] out_length
);

  // Determine if each character is lowercase (97-122)
  wire is_lower0 = (char0 >= 8'h61) && (char0 <= 8'h7A);
  wire is_lower1 = (char1 >= 8'h61) && (char1 <= 8'h7A);
  wire is_lower2 = (char2 >= 8'h61) && (char2 <= 8'h7A);
  wire is_lower3 = (char3 >= 8'h61) && (char3 <= 8'h7A);
  wire is_lower4 = (char4 >= 8'h61) && (char4 <= 8'h7A);
  wire is_lower5 = (char5 >= 8'h61) && (char5 <= 8'h7A);
  wire is_lower6 = (char6 >= 8'h61) && (char6 <= 8'h7A);
  wire is_lower7 = (char7 >= 8'h61) && (char7 <= 8'h7A);

  // Count how many characters are kept (non-lowercase)
  wire [3:0] keep_count = ~is_lower0 + ~is_lower1 + ~is_lower2 + ~is_lower3 +
                            ~is_lower4 + ~is_lower5 + ~is_lower6 + ~is_lower7;

  // Calculate output length (minimum of keep_count and length)
  assign out_length = (keep_count < length) ? keep_count : length;

  // Shift non-lowercase characters to the left
  // Output 0
  assign out0 = (!is_lower0 && (0 < length)) ? char0 :
                 (!is_lower1 && (1 < length)) ? char1 :
                 (!is_lower2 && (2 < length)) ? char2 :
                 (!is_lower3 && (3 < length)) ? char3 :
                 (!is_lower4 && (4 < length)) ? char4 :
                 (!is_lower5 && (5 < length)) ? char5 :
                 (!is_lower6 && (6 < length)) ? char6 :
                 (!is_lower7 && (7 < length)) ? char7 : 8'h00;

  // Output 1
  assign out1 = (!is_lower0 && (1 < length)) ? char1 :
                 (!is_lower1 && (2 < length)) ? char2 :
                 (!is_lower2 && (3 < length)) ? char3 :
                 (!is_lower3 && (4 < length)) ? char4 :
                 (!is_lower4 && (5 < length)) ? char5 :
                 (!is_lower5 && (6 < length)) ? char6 :
                 (!is_lower6 && (7 < length)) ? char7 : 8'h00;

  // Output 2
  assign out2 = (!is_lower0 && (2 < length)) ? char2 :
                 (!is_lower1 && (3 < length)) ? char3 :
                 (!is_lower2 && (4 < length)) ? char4 :
                 (!is_lower3 && (5 < length)) ? char5 :
                 (!is_lower4 && (6 < length)) ? char6 :
                 (!is_lower5 && (7 < length)) ? char7 : 8'h00;

  // Output 3
  assign out3 = (!is_lower0 && (3 < length)) ? char3 :
                 (!is_lower1 && (4 < length)) ? char4 :
                 (!is_lower2 && (5 < length)) ? char5 :
                 (!is_lower3 && (6 < length)) ? char6 :
                 (!is_lower4 && (7 < length)) ? char7 : 8'h00;

  // Output 4
  assign out4 = (!is_lower0 && (4 < length)) ? char4 :
                 (!is_lower1 && (5 < length)) ? char5 :
                 (!is_lower2 && (6 < length)) ? char6 :
                 (!is_lower3 && (7 < length)) ? char7 : 8'h00;

  // Output 5
  assign out5 = (!is_lower0 && (5 < length)) ? char5 :
                 (!is_lower1 && (6 < length)) ? char6 :
                 (!is_lower2 && (7 < length)) ? char7 : 8'h00;

  // Output 6
  assign out6 = (!is_lower0 && (6 < length)) ? char6 :
                 (!is_lower1 && (7 < length)) ? char7 : 8'h00;

  // Output 7
  assign out7 = (!is_lower0 && (7 < length)) ? char7 : 8'h00;

endmodule