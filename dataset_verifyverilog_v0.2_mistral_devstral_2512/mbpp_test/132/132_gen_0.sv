module tuple_to_string (
  input [7:0] char_0,
  input [7:0] char_1,
  input [7:0] char_2,
  input [7:0] char_3,
  input [7:0] char_4,
  input [7:0] char_5,
  input [7:0] char_6,
  input [7:0] char_7,
  input [2:0] length,
  output [63:0] result
);

  wire [63:0] chars = {char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7};

  assign result = (length == 8) ? chars :
                  (length == 7) ? {char_0, char_1, char_2, char_3, char_4, char_5, char_6, 8'h0} :
                  (length == 6) ? {char_0, char_1, char_2, char_3, char_4, char_5, 16'h0} :
                  (length == 5) ? {char_0, char_1, char_2, char_3, char_4, 24'h0} :
                  (length == 4) ? {char_0, char_1, char_2, char_3, 32'h0} :
                  (length == 3) ? {char_0, char_1, char_2, 40'h0} :
                  (length == 2) ? {char_0, char_1, 48'h0} :
                  (length == 1) ? {char_0, 56'h0} :
                  64'h0;

endmodule