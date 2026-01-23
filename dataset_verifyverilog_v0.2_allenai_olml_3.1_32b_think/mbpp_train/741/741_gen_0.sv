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
assign result = (valid_length == 1) ? 1'b1 : 
    ( ( (valid_length > 1) ? (char_1 == char_0) : 1'b1) & 
      ( (valid_length > 2) ? (char_2 == char_0) : 1'b1) & 
      ( (valid_length > 3) ? (char_3 == char_0) : 1'b1) & 
      ( (valid_length > 4) ? (char_4 == char_0) : 1'b1) & 
      ( (valid_length > 5) ? (char_5 == char_0) : 1'b1) & 
      ( (valid_length > 6) ? (char_6 == char_0) : 1'b1) & 
      ( (valid_length > 7) ? (char_7 == char_0) : 1'b1) );
endmodule