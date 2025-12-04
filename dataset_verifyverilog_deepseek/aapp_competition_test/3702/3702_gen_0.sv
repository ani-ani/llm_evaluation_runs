module fibonacci_sequence_map(
  input [19:0] n, // Not used but kept for interface compatibility
  input [19:0] a,
  input [19:0] d,
  output [63:0] b,
  output [63:0] e
);

  logic [48:0] temp_a, temp_d;
  logic [29:0] mod_a, mod_d;

  assign temp_a = 368131125 * a;
  assign mod_a = temp_a % 30'd1000000000;

  assign temp_d = 368131125 * d;
  assign mod_d = temp_d % 30'd1000000000;

  assign b = mod_a * 64'd12000000000 + 64'd1;
  assign e = mod_d * 64'd12000000000;
endmodule