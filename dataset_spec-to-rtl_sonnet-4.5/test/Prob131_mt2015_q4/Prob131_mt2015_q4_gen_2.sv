module ModuleA(
  input x,
  input y,
  output z
);
  assign z = (x ^ y) & x;
endmodule

module ModuleB(
  input x,
  input y,
  output z
);
  assign z = ~(x ^ y);
endmodule

module TopModule(
  input x,
  input y,
  output z
);
  wire a1_out, a2_out, b1_out, b2_out;
  wire or_out, and_out;
  
  ModuleA a1(.x(x), .y(y), .z(a1_out));
  ModuleA a2(.x(x), .y(y), .z(a2_out));
  ModuleB b1(.x(x), .y(y), .z(b1_out));
  ModuleB b2(.x(x), .y(y), .z(b2_out));
  
  assign or_out = a1_out | b1_out;
  assign and_out = a2_out & b2_out;
  assign z = or_out ^ and_out;
endmodule