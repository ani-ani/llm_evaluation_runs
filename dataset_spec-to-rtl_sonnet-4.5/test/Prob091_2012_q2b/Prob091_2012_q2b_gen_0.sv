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

  // Y1 is the next state for flip-flop y[1] (state B)
  // Transitions to B:
  // A --1--> B
  // Therefore: Y1 = y[0] & w
  assign Y1 = y[0] & w;

  // Y3 is the next state for flip-flop y[3] (state D)
  // Transitions to D:
  // B --0--> D
  // C --0--> D
  // E --0--> D
  // F --0--> D
  // Therefore: Y3 = (y[1] & ~w) | (y[2] & ~w) | (y[4] & ~w) | (y[5] & ~w)
  assign Y3 = (y[1] & ~w) | (y[2] & ~w) | (y[4] & ~w) | (y[5] & ~w);

endmodule