module parabola_directrix (
  input [15:0] a,
  input [15:0] b,
  input [15:0] c,
  output [31:0] directrix
);

  wire [31:0] b_squared = $signed(b) * $signed(b);
  wire [31:0] b_squared_plus_1 = b_squared + 1;
  wire [31:0] temp = (b_squared_plus_1 << 2) * $signed(a);
  assign directrix = $signed(c) - temp;

endmodule