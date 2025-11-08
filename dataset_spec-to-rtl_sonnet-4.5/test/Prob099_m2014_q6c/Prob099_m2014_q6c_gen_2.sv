module TopModule(
  input [5:0] y,
  input w,
  output Y1,
  output Y3
);

  // State encoding (one-hot):
  // A = y[0] = 000001
  // B = y[1] = 000010
  // C = y[2] = 000100
  // D = y[3] = 001000
  // E = y[4] = 010000
  // F = y[5] = 100000

  // Next state logic for Y1 (next state B):
  // B is the next state when:
  // - From A with w=0
  // Transition: A --0--> B
  assign Y1 = y[0] & ~w;

  // Next state logic for Y3 (next state D):
  // D is the next state when:
  // - From B with w=1: B --1--> D
  // - From C with w=1: C --1--> D
  // - From E with w=1: E --1--> D
  // - From F with w=1: F --1--> D
  assign Y3 = (y[1] & w) | (y[2] & w) | (y[4] & w) | (y[5] & w);

endmodule