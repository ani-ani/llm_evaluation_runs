module ModuleA(input x, y, output z);
  assign z = (x ^ y) & x;
endmodule

module ModuleB(input x, y, output z);
  assign z = ~(x ^ y);
endmodule

module TopModule(input x, y, output z);
  wire A1_z, B1_z, A2_z, B2_z;
  wire or_out, and_out;
  
  ModuleA A1(.x(x), .y(y), .z(A1_z));
  ModuleB B1(.x(x), .y(y), .z(B1_z));
  ModuleA A2(.x(x), .y(y), .z(A2_z));
  ModuleB B2(.x(x), .y(y), .z(B2_z));
  
  assign or_out = A1_z | B1_z;
  assign and_out = A2_z & B2_z;
  assign z = or_out ^ and_out;
endmodule