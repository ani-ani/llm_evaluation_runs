module parity_checker(input reg [7:0] x, output odd_parity);
  wire [7:0] y1, y2;
  wire [7:0] y0 = x;
  assign y1 = y0 ^ (y0 >> 1);
  assign y2 = y1 ^ (y1 >> 2);
  assign odd_parity = (y2 ^ (y2 >> 4))[0];
endmodule