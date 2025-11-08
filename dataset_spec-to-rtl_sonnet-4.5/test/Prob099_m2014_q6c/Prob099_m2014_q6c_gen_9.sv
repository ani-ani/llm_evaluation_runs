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

  // Y1 corresponds to next state B (y[1])
  // B is the next state when:
  // - Currently in A and w=0
  assign Y1 = y[0] & ~w;

  // Y3 corresponds to next state D (y[3])
  // D is the next state when:
  // - Currently in B and w=1
  // - Currently in C and w=1
  // - Currently in E and w=1
  // - Currently in F and w=1
  assign Y3 = (y[1] & w) | (y[2] & w) | (y[4] & w) | (y[5] & w);

endmodule