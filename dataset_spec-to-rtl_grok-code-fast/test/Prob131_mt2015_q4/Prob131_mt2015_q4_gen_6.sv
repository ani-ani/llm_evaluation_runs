module TopModule(input x, input y, output z);
  wire za1, zb1, za2, zb2;
  wire or_out, and_out;

  assign or_out = za1 | zb1;
  assign and_out = za2 & zb2;
  assign z = or_out ^ and_out;

  A a1(.a(x), .b(y), .z(za1));
  A a2(.a(x), .b(y), .z(za2));
  B b1(.a(x), .b(y), .z(zb1));
  B b2(.a(x), .b(y), .z(zb2));
endmodule

module A(input a, input b, output z);
  assign z = (a ^ b) & a;
endmodule

module B(input a, input b, output z);
  assign z = a & b;
endmodule