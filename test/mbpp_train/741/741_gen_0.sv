module all_chars_same(
  input  wire [63:0] s,
  input  wire [2:0]  len,
  output wire        all_same
);

  wire [7:0] first_char;
  assign first_char = s[63:56];

  wire match1 = (len <= 3'd1) ? 1'b1 : (s[55:48] == first_char);
  wire match2 = (len <= 3'd2) ? 1'b1 : (s[47:40] == first_char);
  wire match3 = (len <= 3'd3) ? 1'b1 : (s[39:32] == first_char);
  wire match4 = (len <= 3'd4) ? 1'b1 : (s[31:24] == first_char);
  wire match5 = (len <= 3'd5) ? 1'b1 : (s[23:16] == first_char);
  wire match6 = (len <= 3'd6) ? 1'b1 : (s[15:8]  == first_char);
  wire match7 = (len <= 3'd7) ? 1'b1 : (s[7:0]   == first_char);

  assign all_same = match1 & match2 & match3 & match4 & match5 & match6 & match7;

endmodule