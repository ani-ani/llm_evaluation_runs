module hexagon_triangles (
  input [7:0] a1,
  input [7:0] a2,
  input [7:0] a3,
  input [7:0] a4,
  input [7:0] a5,
  input [7:0] a6,
  output [31:0] count
);

  wire [15:0] sum_a1_a2_a3 = a1 + a2 + a3;
  wire [31:0] sum_squared = sum_a1_a2_a3 * sum_a1_a2_a3;
  wire [31:0] a1_squared = a1 * a1;
  wire [31:0] a3_squared = a3 * a3;
  wire [31:0] a4_squared = a4 * a4;

  assign count = sum_squared - a1_squared - a3_squared - a4_squared;

endmodule