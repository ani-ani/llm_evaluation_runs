module starts_with_vowel(input [63:0] str_packed, output result);
  wire [7:0] first_char = str_packed[63:56];
  assign result = (first_char == 8'h41) || // 'A'
                  (first_char == 8'h45) || // 'E'
                  (first_char == 8'h49) || // 'I'
                  (first_char == 8'h4F) || // 'O'
                  (first_char == 8'h55) || // 'U'
                  (first_char == 8'h61) || // 'a'
                  (first_char == 8'h65) || // 'e'
                  (first_char == 8'h69) || // 'i'
                  (first_char == 8'h6F) || // 'o'
                  (first_char == 8'h75);   // 'u'
endmodule