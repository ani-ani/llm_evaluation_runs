module ModuleA(input x, y, output z);
  assign z = (x ^ y) & x;
endmodule

module ModuleB(input x, y, output z);
  assign z = ~(x ^ y);
endmodule

module TopModule(input x, y, output z);
  wire zA1, zB1, zA2, zB2;
  wire OR_out, AND_out;

  ModuleA A1(.x(x), .y(y), .z(zA1));
  ModuleB B1(.x(x), .y(y), .z(zB1));
  ModuleA A2(.x(x), .y(y), .z(zA2));
  ModuleB B2(.x(x), .y(y), .z(zB2));

  assign OR_out = zA1 | zB1;
  assign AND_out = zA2 & zB2;
  assign z = OR_out ^ AND_out;
endmodule