module TopModule(
  input [5:0] y,
  input w,
  output Y1,
  output Y3
);

  // State encoding (one-hot):
  // A = 6'b000001 (y[0])
  // B = 6'b000010 (y[1])
  // C = 6'b000100 (y[2])
  // D = 6'b001000 (y[3])
  // E = 6'b010000 (y[4])
  // F = 6'b100000 (y[5])

  // Y1 corresponds to next state B (y[1])
  // B is reached from:
  // - A when w=0
  // Looking at state transitions:
  // A --0--> B
  assign Y1 = y[0] & ~w;

  // Y3 corresponds to next state D (y[3])
  // D is reached from:
  // - B when w=1
  // - C when w=1
  // - E when w=1
  // - F when w=1
  assign Y3 = (y[1] & w) | (y[2] & w) | (y[4] & w) | (y[5] & w);

endmodule