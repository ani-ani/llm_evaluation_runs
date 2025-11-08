module A(input x, input y, output za);
  assign za = x && ~y;
endmodule

module B(input x, input y, output zb);
  assign zb = x ~^ y;
endmodule

module TopModule(input x, input y, output z);
  wire za1, za2, zb1, zb2;
  A a1(.x(x), .y(y), .za(za1));
  A a2(.x(x), .y(y), .za(za2));
  B b1(.x(x), .y(y), .zb(zb1));
  B b2(.x(x), .y(y), .zb(zb2));
  wire or_out = za1 || zb1;
  wire and_out = za2 && zb2;
  assign z = or_out ^ and_out;
endmodule