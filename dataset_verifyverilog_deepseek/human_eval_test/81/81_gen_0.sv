module gpa_to_letter (
  input [5:0] scaled_gpa,
  output reg [4:0] letter_code
);

  always_comb begin
    if (scaled_gpa >= 40) letter_code = 5'b00000;
    else if (scaled_gpa >= 37) letter_code = 5'b00001;
    else if (scaled_gpa >= 33) letter_code = 5'b00010;
    else if (scaled_gpa >= 30) letter_code = 5'b00011;
    else if (scaled_gpa >= 27) letter_code = 5'b00100;
    else if (scaled_gpa >= 23) letter_code = 5'b00101;
    else if (scaled_gpa >= 20) letter_code = 5'b00110;
    else if (scaled_gpa >= 17) letter_code = 5'b00111;
    else if (scaled_gpa >= 13) letter_code = 5'b01000;
    else if (scaled_gpa >= 10) letter_code = 5'b01001;
    else if (scaled_gpa >= 7) letter_code = 5'b01010;
    else if (scaled_gpa >= 1) letter_code = 5'b01011;
    else letter_code = 5'b01100;
  end

endmodule