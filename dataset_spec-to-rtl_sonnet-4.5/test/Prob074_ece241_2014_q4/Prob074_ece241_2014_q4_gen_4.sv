module TopModule(
  input  clk,
  input  x,
  output z
);

  reg q1, q2, q3;
  wire d1, d2, d3;

  // XOR gate: x XOR q1
  assign d1 = x ^ q1;

  // AND gate: x AND ~q2
  assign d2 = x & ~q2;

  // OR gate: x OR ~q3
  assign d3 = x | ~q3;

  // D flip-flops with positive edge trigger and initial value of 0
  always @(posedge clk) begin
    q1 <= d1;
    q2 <= d2;
    q3 <= d3;
  end

  // Three-input NOR gate
  assign z = ~(q1 | q2 | q3);

  // Initialize flip-flops to zero
  initial begin
    q1 = 1'b0;
    q2 = 1'b0;
    q3 = 1'b0;
  end

endmodule