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

  // State transitions:
  // A --0--> B, A --1--> A
  // B --0--> C, B --1--> D
  // C --0--> E, C --1--> D
  // D --0--> F, D --1--> A
  // E --0--> E, E --1--> D
  // F --0--> C, F --1--> D

  // Y1 corresponds to next state B (y[1])
  // B is the next state when:
  // - Current state A and w=0
  assign Y1 = y[0] & ~w;

  // Y3 corresponds to next state D (y[3])
  // D is the next state when:
  // - Current state B and w=1
  // - Current state C and w=1
  // - Current state E and w=1
  // - Current state F and w=1
  assign Y3 = (y[1] & w) | (y[2] & w) | (y[4] & w) | (y[5] & w);

endmodule