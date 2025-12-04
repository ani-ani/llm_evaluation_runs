module gpa_to_letter (
  input  [5:0] scaled_gpa,
  output reg [4:0] letter_code
);

  always @* begin
    if (scaled_gpa >= 6'd40)
      letter_code = 5'b00000; // A+
    else if (scaled_gpa >= 6'd37)
      letter_code = 5'b00001; // A
    else if (scaled_gpa >= 6'd33)
      letter_code = 5'b00010; // A-
    else if (scaled_gpa >= 6'd30)
      letter_code = 5'b00011; // B+
    else if (scaled_gpa >= 6'd27)
      letter_code = 5'b00100; // B
    else if (scaled_gpa >= 6'd23)
      letter_code = 5'b00101; // B-
    else if (scaled_gpa >= 6'd20)
      letter_code = 5'b00110; // C+
    else if (scaled_gpa >= 6'd17)
      letter_code = 5'b00111; // C
    else if (scaled_gpa >= 6'd13)
      letter_code = 5'b01000; // C-
    else if (scaled_gpa >= 6'd10)
      letter_code = 5'b01001; // D+
    else if (scaled_gpa >= 6'd7)
      letter_code = 5'b01010; // D
    else if (scaled_gpa >= 6'd1)
      letter_code = 5'b01011; // D-
    else
      letter_code = 5'b01100; // E
  end

endmodule