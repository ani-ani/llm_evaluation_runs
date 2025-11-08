module TopModule(
  input reg [4:0] a,
  input reg [4:0] b,
  input reg [4:0] c,
  input reg [4:0] d,
  input reg [4:0] e,
  input reg [4:0] f,
  output [7:0] w,
  output [7:0] x,
  output [7:0] y,
  output [7:0] z
);
  assign {w, x, y, z} = {a, b, c, d, e, f, 2'b11};
endmodule