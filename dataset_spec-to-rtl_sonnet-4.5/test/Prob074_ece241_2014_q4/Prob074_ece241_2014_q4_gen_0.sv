module TopModule(
  input clk,
  input x,
  output z
);

  reg q_xor, q_and, q_or;
  wire d_xor, d_and, d_or;

  // XOR gate: x XOR q_xor
  assign d_xor = x ^ q_xor;

  // AND gate: x AND ~q_and
  assign d_and = x & ~q_and;

  // OR gate: x OR ~q_or
  assign d_or = x | ~q_or;

  // D flip-flops with positive edge trigger and initial reset to 0
  always @(posedge clk) begin
    q_xor <= d_xor;
    q_and <= d_and;
    q_or <= d_or;
  end

  // Three-input NOR gate
  assign z = ~(q_xor | q_and | q_or);

endmodule