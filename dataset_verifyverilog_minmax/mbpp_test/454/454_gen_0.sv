module find_z (
  input reg [63:0] text,
  output reg match_found
);

always @* begin
  match_found = 1'b0;
  if (text[7:0] == 8'd122) match_found = 1'b1;
  if (text[15:8] == 8'd122) match_found = 1'b1;
  if (text[23:16] == 8'd122) match_found = 1'b1;
  if (text[31:24] == 8'd122) match_found = 1'b1;
  if (text[39:32] == 8'd122) match_found = 1'b1;
  if (text[47:40] == 8'd122) match_found = 1'b1;
  if (text[55:48] == 8'd122) match_found = 1'b1;
  if (text[63:56] == 8'd122) match_found = 1'b1;
end

endmodule