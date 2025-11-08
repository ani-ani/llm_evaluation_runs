module TopModule(
  input  x,
  input  y,
  output z
);

  wire a1_out, a2_out, b1_out, b2_out;
  wire or_out, and_out;

  // Module A implements z = (x^y) & x
  module_a a1(.x(x), .y(y), .z(a1_out));
  module_a a2(.x(x), .y(y), .z(a2_out));

  // Module B instances
  module_b b1(.x(x), .y(y), .z(b1_out));
  module_b b2(.x(x), .y(y), .z(b2_out));

  // OR gate for first A and B outputs
  assign or_out = a1_out | b1_out;

  // AND gate for second A and B outputs
  assign and_out = a2_out & b2_out;

  // XOR gate for final output
  assign z = or_out ^ and_out;

endmodule

module module_a(
  input  x,
  input  y,
  output z
);
  assign z = (x ^ y) & x;
endmodule

module module_b(
  input  x,
  input  y,
  output z
);
  // From waveform analysis:
  // x=0, y=0 -> z=1
  // x=1, y=0 -> z=0
  // x=0, y=1 -> z=0
  // x=1, y=1 -> z=1
  // This is XNOR: z = ~(x ^ y)
  assign z = ~(x ^ y);
endmodule