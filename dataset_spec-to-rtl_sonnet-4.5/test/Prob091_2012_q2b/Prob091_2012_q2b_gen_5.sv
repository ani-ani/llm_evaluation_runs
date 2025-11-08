module TopModule(
  input [5:0] y,
  input w,
  output Y1,
  output Y3
);

  // State encoding:
  // y[0] = A (000001)
  // y[1] = B (000010)
  // y[2] = C (000100)
  // y[3] = D (001000)
  // y[4] = E (010000)
  // y[5] = F (100000)

  // Y1 is the next state for flip-flop y[1] (state B)
  // State B is reached from:
  // - State A when w=1
  // Transitions to B: A --1--> B
  assign Y1 = y[0] & w;

  // Y3 is the next state for flip-flop y[3] (state D)
  // State D is reached from:
  // - State B when w=0: B --0--> D
  // - State C when w=0: C --0--> D
  // - State D when w=0: D --0--> A (no, this goes to A)
  // - State E when w=0: E --0--> D
  // - State F when w=0: F --0--> D
  // Transitions to D: B --0--> D, C --0--> D, E --0--> D, F --0--> D
  assign Y3 = (y[1] & ~w) | (y[2] & ~w) | (y[4] & ~w) | (y[5] & ~w);

endmodule