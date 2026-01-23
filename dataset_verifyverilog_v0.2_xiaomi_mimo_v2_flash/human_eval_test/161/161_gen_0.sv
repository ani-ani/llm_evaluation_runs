module string_transform(
  input [7:0] char_0,
  input [7:0] char_1,
  input [7:0] char_2,
  input [7:0] char_3,
  input [7:0] char_4,
  input [7:0] char_5,
  input [7:0] char_6,
  input [7:0] char_7,
  output [7:0] out_0,
  output [7:0] out_1,
  output [7:0] out_2,
  output [7:0] out_3,
  output [7:0] out_4,
  output [7:0] out_5,
  output [7:0] out_6,
  output [7:0] out_7
);

  // Helper function to check if a character is a letter
  function automatic is_letter;
    input [7:0] c;
    begin
      is_letter = ((c >= 8'h41 && c <= 8'h5A) || (c >= 8'h61 && c <= 8'h7A));
    end
  endfunction

  // Helper function to toggle case of a letter (or keep unchanged)
  function automatic [7:0] toggle_case;
    input [7:0] c;
    begin
      if ((c >= 8'h41 && c <= 8'h5A) || (c >= 8'h61 && c <= 8'h7A))
        toggle_case = c ^ 8'h20;
      else
        toggle_case = c;
    end
  endfunction

  // Intermediate values for toggle case
  wire [7:0] char_0_toggle = toggle_case(char_0);
  wire [7:0] char_1_toggle = toggle_case(char_1);
  wire [7:0] char_2_toggle = toggle_case(char_2);
  wire [7:0] char_3_toggle = toggle_case(char_3);
  wire [7:0] char_4_toggle = toggle_case(char_4);
  wire [7:0] char_5_toggle = toggle_case(char_5);
  wire [7:0] char_6_toggle = toggle_case(char_6);
  wire [7:0] char_7_toggle = toggle_case(char_7);

  // Detect if any letter exists
  wire has_letter = is_letter(char_0) | is_letter(char_1) | is_letter(char_2) | is_letter(char_3) |
                    is_letter(char_4) | is_letter(char_5) | is_letter(char_6) | is_letter(char_7);

  // Output logic
  assign out_0 = has_letter ? char_0_toggle : char_7;
  assign out_1 = has_letter ? char_1_toggle : char_6;
  assign out_2 = has_letter ? char_2_toggle : char_5;
  assign out_3 = has_letter ? char_3_toggle : char_4;
  assign out_4 = has_letter ? char_4_toggle : char_3;
  assign out_5 = has_letter ? char_5_toggle : char_2;
  assign out_6 = has_letter ? char_6_toggle : char_1;
  assign out_7 = has_letter ? char_7_toggle : char_0;

endmodule