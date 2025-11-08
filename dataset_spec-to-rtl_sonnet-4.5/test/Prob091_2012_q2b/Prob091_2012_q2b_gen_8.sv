module TopModule(
  input [5:0] y,
  input w,
  output Y1,
  output Y3
);

  // State encoding (one-hot):
  // y[0] = A (000001)
  // y[1] = B (000010)
  // y[2] = C (000100)
  // y[3] = D (001000)
  // y[4] = E (010000)
  // y[5] = F (100000)

  // Transition table:
  // A --1--> B
  // A --0--> A
  // B --1--> C
  // B --0--> D
  // C --1--> E
  // C --0--> D
  // D --1--> F
  // D --0--> A
  // E --1--> E
  // E --0--> D
  // F --1--> C
  // F --0--> D

  // Y1 is the next state for y[1] (state B)
  // State B is reached when:
  // - Current state is A and w = 1
  assign Y1 = y[0] & w;

  // Y3 is the next state for y[3] (state D)
  // State D is reached when:
  // - Current state is B and w = 0
  // - Current state is C and w = 0
  // - Current state is E and w = 0
  // - Current state is F and w = 0
  assign Y3 = (y[1] & ~w) | (y[2] & ~w) | (y[4] & ~w) | (y[5] & ~w);

endmodule