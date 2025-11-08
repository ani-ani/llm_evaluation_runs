module A(input x, y, output z);
  assign z = (x ^ y) & x;
endmodule

module B(input x, y, output z);
  assign z = ~(x ^ y);
endmodule

module TopModule(input x, y, output z);
  wire a1, a2, b1, b2;
  A A1(.x(x), .y(y), .z(a1));
  B B1(.x(x), .y(y), .z(b1));
  A A2(.x(x), .y(y), .z(a2));
  B B2(.x(x), .y(y), .z(b2));
  wire or_out = a1 | b1;
  wire and_out = a2 & b2;
  assign z = or_out ^ and_out;
endmodule