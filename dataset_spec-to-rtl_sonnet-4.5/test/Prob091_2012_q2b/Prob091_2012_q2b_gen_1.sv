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

  // Next state logic for Y1 (next state for flip-flop y[1], state B):
  // B is the next state when:
  // - Current state is A and w = 1
  assign Y1 = y[0] & w;

  // Next state logic for Y3 (next state for flip-flop y[3], state D):
  // D is the next state when:
  // - Current state is B and w = 0
  // - Current state is C and w = 0
  // - Current state is E and w = 0
  // - Current state is F and w = 0
  assign Y3 = (y[1] & ~w) | (y[2] & ~w) | (y[4] & ~w) | (y[5] & ~w);

endmodule