module case_reverse_or_invert (
  input [63:0] str_in,
  output [63:0] str_out
);

  logic [63:0] converted_chars;
  logic [7:0] is_letter;
  logic any_letter;
  logic [63:0] reversed_chars;

  generate
    genvar i;
    for (i=0; i<8; i=i+1) begin : char_convert
      logic [7:0] current_char, conv_char;
      logic is_lower, is_upper;

      assign current_char = str_in[63 - (i*8) -: 8];
      assign is_lower = (current_char >= 8'd97) && (current_char <= 8'd122);
      assign is_upper = (current_char >= 8'd65) && (current_char <= 8'd90);
      assign conv_char = (is_lower) ? (current_char - 8'd32) : 
                         (is_upper) ? (current_char + 8'd32) : 
                         current_char;
      assign converted_chars[63 - (i*8) -: 8] = conv_char;
      assign is_letter[i] = is_lower | is_upper;
    end
  endgenerate

  assign any_letter = |is_letter;

  generate
    genvar j;
    for (j=0; j<8; j=j+1) begin : reverse_gen
      assign reversed_chars[63 - (j*8) -: 8] = converted_chars[(7-j)*8 +: 8];
    end
  endgenerate

  assign str_out = (any_letter) ? converted_chars : reversed_chars;

endmodule