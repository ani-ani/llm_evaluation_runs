module ModuleA(input x, y, output z);
  assign z = (x ^ y) & x;
endmodule

module ModuleB(input x, y, output z);
  assign z = ~(x ^ y);
endmodule

module TopModule(input x, y, output z);
  wire a1_z, a2_z;
  wire b1_z, b2_z;
  wire or_out, and_out;

  ModuleA A1(.x(x), .y(y), .z(a1_z));
  ModuleB B1(.x(x), .y(y), .z(b1_z));
  ModuleA A2(.x(x), .y(y), .z(a2_z));
  ModuleB B2(.x(x), .y(y), .z(b2_z));

  assign or_out = a1_z | b1_z;
  assign and_out = a2_z & b2_z;
  assign z = or_out ^ and_out;
endmodule