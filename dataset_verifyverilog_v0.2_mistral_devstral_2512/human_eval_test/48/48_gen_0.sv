module palindrome_checker (
  input [7:0] char_0,
  input [7:0] char_1,
  input [7:0] char_2,
  input [7:0] char_3,
  input [7:0] char_4,
  input [7:0] char_5,
  input [7:0] char_6,
  input [7:0] char_7,
  input [2:0] valid_count,
  output reg is_palindrome
);

  always @* begin
    is_palindrome = 1'b1; // Default to true
    
    case (valid_count)
      3'd0: is_palindrome = 1'b1; // Empty string is palindrome
      3'd1: is_palindrome = 1'b1; // Single character is palindrome
      3'd2: is_palindrome = (char_0 == char_1);
      3'd3: is_palindrome = (char_0 == char_2);
      3'd4: is_palindrome = (char_0 == char_3) && (char_1 == char_2);
      3'd5: is_palindrome = (char_0 == char_4) && (char_1 == char_3);
      3'd6: is_palindrome = (char_0 == char_5) && (char_1 == char_4) && (char_2 == char_3);
      3'd7: is_palindrome = (char_0 == char_6) && (char_1 == char_5) && (char_2 == char_4);
      3'd8: is_palindrome = (char_0 == char_7) && (char_1 == char_6) && (char_2 == char_5) && (char_3 == char_4);
      default: is_palindrome = 1'b0; // Invalid count
    endcase
  end

endmodule