module find_z(
  input  [63:0] text,
  output       match_found
);

  wire [7:0] byte0 = text[63:56];
  wire [7:0] byte1 = text[55:48];
  wire [7:0] byte2 = text[47:40];
  wire [7:0] byte3 = text[39:32];
  wire [7:0] byte4 = text[31:24];
  wire [7:0] byte5 = text[23:16];
  wire [7:0] byte6 = text[15:8];
  wire [7:0] byte7 = text[7:0];

  assign match_found = (byte0 == 8'd122) |
                       (byte1 == 8'd122) |
                       (byte2 == 8'd122) |
                       (byte3 == 8'd122) |
                       (byte4 == 8'd122) |
                       (byte5 == 8'd122) |
                       (byte6 == 8'd122) |
                       (byte7 == 8'd122);

endmodule