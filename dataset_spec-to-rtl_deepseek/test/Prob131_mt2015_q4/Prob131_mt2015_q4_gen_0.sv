module ModuleA(input x, y, output z);
  assign z = x & ~y;
endmodule

module ModuleB(input x, y, output z);
  assign z = ~(x ^ y);
endmodule

module TopModule(input x, y, output z);
  wire z_a1, z_a2, z_b1, z_b2;
  wire or_out, and_out;
  ModuleA a1(.x(x), .y(y), .z(z_a1));
  ModuleB b1(.x(x), .y(y), .z(z_b1));
  ModuleA a2(.x(x), .y(y), .z(z_a2));
  ModuleB b2(.x(x), .y(y), .z(z_b2));
  assign or_out = z_a1 | z_b1;
  assign and_out = z_a2 & z_b2;
  assign z = or_out ^ and_out;
endmodule