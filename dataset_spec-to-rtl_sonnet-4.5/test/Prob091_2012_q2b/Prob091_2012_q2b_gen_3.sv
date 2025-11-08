module TopModule(
  input  [5:0] y,
  input  w,
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

  // State transitions:
  // A (y[0]): w=1 -> B, w=0 -> A
  // B (y[1]): w=1 -> C, w=0 -> D
  // C (y[2]): w=1 -> E, w=0 -> D
  // D (y[3]): w=1 -> F, w=0 -> A
  // E (y[4]): w=1 -> E, w=0 -> D
  // F (y[5]): w=1 -> C, w=0 -> D

  // Y1 (next state for y[1], which is state B)
  // B is the next state when:
  // - Current state is A (y[0]) and w=1
  assign Y1 = y[0] & w;

  // Y3 (next state for y[3], which is state D)
  // D is the next state when:
  // - Current state is B (y[1]) and w=0
  // - Current state is C (y[2]) and w=0
  // - Current state is E (y[4]) and w=0
  // - Current state is F (y[5]) and w=0
  assign Y3 = (y[1] & ~w) | (y[2] & ~w) | (y[4] & ~w) | (y[5] & ~w);

endmodule