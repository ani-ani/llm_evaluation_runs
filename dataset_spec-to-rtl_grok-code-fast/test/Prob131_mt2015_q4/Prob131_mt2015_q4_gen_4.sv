module A(input x, input y, output z);
  assign z = (x ^ y) & x;
endmodule

module B(input x, input y, output z);
  assign z = ~(x ^ y);
endmodule

module top(input x, input y, output z);
  wire a1z, a2z, b1z, b2z;
  A a1(.x(x), .y(y), .z(a1z));
  A a2(.x(x), .y(y), .z(a2z));
  B b1(.x(x), .y(y), .z(b1z));
  B b2(.x(x), .y(y), .z(b2z));
  wire or_out = a1z | b1z;
  wire and_out = a2z & b2z;
  assign z = or_out ^ and_out;
endmodule