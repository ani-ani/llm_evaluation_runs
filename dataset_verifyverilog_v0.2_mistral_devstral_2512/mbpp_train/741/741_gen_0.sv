module all_characters_same (
  input [7:0] char_0,
  input [7:0] char_1,
  input [7:0] char_2,
  input [7:0] char_3,
  input [7:0] char_4,
  input [7:0] char_5,
  input [7:0] char_6,
  input [7:0] char_7,
  input [2:0] valid_length,
  output reg result
);

  always @* begin
    case (valid_length)
      3'b001: result = 1'b1; // Only one character, always true
      3'b010: result = (char_0 == char_1);
      3'b011: result = (char_0 == char_1) && (char_0 == char_2);
      3'b100: result = (char_0 == char_1) && (char_0 == char_2) && (char_0 == char_3);
      3'b101: result = (char_0 == char_1) && (char_0 == char_2) && (char_0 == char_3) && (char_0 == char_4);
      3'b110: result = (char_0 == char_1) && (char_0 == char_2) && (char_0 == char_3) && (char_0 == char_4) && (char_0 == char_5);
      3'b111: result = (char_0 == char_1) && (char_0 == char_2) && (char_0 == char_3) && (char_0 == char_4) && (char_0 == char_5) && (char_0 == char_6);
      3'b1000: result = (char_0 == char_1) && (char_0 == char_2) && (char_0 == char_3) && (char_0 == char_4) && (char_0 == char_5) && (char_0 == char_6) && (char_0 == char_7);
      default: result = 1'b0; // Invalid valid_length, default to false
    endcase
  end

endmodule