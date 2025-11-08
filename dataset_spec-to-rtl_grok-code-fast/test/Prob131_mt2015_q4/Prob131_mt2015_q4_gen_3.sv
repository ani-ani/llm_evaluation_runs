module TopModule(
  input x,
  input y,
  output z
);
  wire za1, za2, zb1, zb2;
  wire or_out, and_out;

  // Instantiate A submodules
  A_sub a1 (.a(x), .b(y), .z(za1));
  A_sub a2 (.a(x), .b(y), .z(za2));

  // Instantiate B submodules
  B_sub b1 (.a(x), .b(y), .z(zb1));
  B_sub b2 (.a(x), .b(y), .z(zb2));

  // OR of first A and first B
  assign or_out = za1 | zb1;

  // AND of second A and second B
  assign and_out = za2 & zb2;

  // XOR of or_out and and_out
  assign z = or_out ^ and_out;
endmodule

module A_sub(
  input a,
  input b,
  output z
);
  assign z = (a ^ b) & a;
endmodule

module B_sub(
  input a,
  input b,
  output z
);
  assign z = a ~^ b;
endmodule