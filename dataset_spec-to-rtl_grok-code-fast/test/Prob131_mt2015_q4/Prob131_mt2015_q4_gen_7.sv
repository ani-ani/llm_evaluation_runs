module A(input x, input y, output z);
  assign z = (x ^ y) & x;
endmodule

module B(input x, input y, output z);
  assign z = x ~^ y;
endmodule

module TopModule(input x, input y, output z);
  wire za1, zb1, za2, zb2, o1, o2;

  A A1(.x(x), .y(y), .z(za1));
  B B1(.x(x), .y(y), .z(zb1));
  A A2(.x(x), .y(y), .z(za2));
  B B2(.x(x), .y(y), .z(zb2));

  assign o1 = za1 | zb1;
  assign o2 = za2 & zb2;
  assign z = o1 ^ o2;
endmodule