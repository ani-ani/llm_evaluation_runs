module reconstruct_ring(
  input  [31:0] y0,
  input  [31:0] y1,
  input  [31:0] y2,
  input  [31:0] y3,
  output [31:0] x0,
  output [31:0] x1,
  output [31:0] x2,
  output [31:0] x3
);

  wire [33:0] sum_y; // enough bits to hold sum of four 32-bit numbers
  wire [33:0] S_wide;

  assign sum_y = y0 + y1 + y2 + y3;
  assign S_wide = sum_y / 3;

  assign x0 = S_wide[31:0] - y2;
  assign x1 = S_wide[31:0] - y3;
  assign x2 = S_wide[31:0] - y0;
  assign x3 = S_wide[31:0] - y1;

endmodule