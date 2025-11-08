module ModuleA(input x, y, output z);
  assign z = (x ^ y) & x;
endmodule

module ModuleB(input x, y, output z);
  assign z = ~(x ^ y);
endmodule

module TopModule(input x, y, output z);
  wire a1_out, b1_out, a2_out, b2_out;
  wire or_out, and_out;
  
  ModuleA A1(.x(x), .y(y), .z(a1_out));
  ModuleB B1(.x(x), .y(y), .z(b1_out));
  ModuleA A2(.x(x), .y(y), .z(a2_out));
  ModuleB B2(.x(x), .y(y), .z(b2_out));
  
  assign or_out = a1_out | b1_out;
  assign and_out = a2_out & b2_out;
  assign z = or_out ^ and_out;
endmodule