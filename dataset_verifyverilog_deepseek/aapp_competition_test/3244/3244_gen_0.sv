module reconstruct_ring (
  input [31:0] y0,
  input [31:0] y1,
  input [31:0] y2,
  input [31:0] y3,
  output [31:0] x0,
  output [31:0] x1,
  output [31:0] x2,
  output [31:0] x3
);

  wire [33:0] sum_y = y0 + y1 + y2 + y3;
  wire [31:0] S = sum_y / 3;

  assign x0 = S - y2;
  assign x1 = S - y3;
  assign x2 = S - y0;
  assign x3 = S - y1;

endmodule