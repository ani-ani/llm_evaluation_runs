module parity_checker(
  input  [7:0] x,
  output       odd_parity
);

  wire [7:0] y1;
  wire [7:0] y2;
  wire [7:0] y3;

  assign y1 = x  ^ (x  >> 1);
  assign y2 = y1 ^ (y1 >> 2);
  assign y3 = y2 ^ (y2 >> 4);

  assign odd_parity = y3[0];

endmodule