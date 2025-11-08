module TopModule(
  input  clk,
  input  x,
  output z
);

  // D flip-flop outputs
  reg ff_xor, ff_and, ff_or;
  
  // Gate outputs (D flip-flop inputs)
  wire d_xor, d_and, d_or;
  
  // XOR gate: x XOR ff_xor_out
  assign d_xor = x ^ ff_xor;
  
  // AND gate: x AND (NOT ff_and_out)
  assign d_and = x & (~ff_and);
  
  // OR gate: x OR (NOT ff_or_out)
  assign d_or = x | (~ff_or);
  
  // D flip-flops with positive edge trigger and initial value 0
  always @(posedge clk) begin
    ff_xor <= d_xor;
    ff_and <= d_and;
    ff_or <= d_or;
  end
  
  // Three-input NOR gate
  assign z = ~(ff_xor | ff_and | ff_or);

endmodule