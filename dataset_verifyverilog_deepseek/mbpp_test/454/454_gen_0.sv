module find_z(input [63:0] text, output match_found);
  assign match_found = |{ (text[63:56] == 8'd122), (text[55:48] == 8'd122), (text[47:40] == 8'd122), (text[39:32] == 8'd122), (text[31:24] == 8'd122), (text[23:16] == 8'd122), (text[15:8] == 8'd122), (text[7:0] == 8'd122) };
endmodule