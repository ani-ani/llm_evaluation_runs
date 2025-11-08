module A(input x, y, output z);
  assign z = (x ^ y) & x;
endmodule
module B(input x, y, output z);
  reg previous_x = 0;
  reg previous_y = 0;
  reg state = 1'b1;
  assign z = state;
  always @(x or y) begin
    if (x && ~previous_x) state = ~state;
    if (y && ~previous_y) state = 1'b0;
    previous_x = x;
    previous_y = y;
  end
endmodule
module top(input x, y, output z);
  wire z_a1, z_a2, z_b1, z_b2;
  A a1(.x(x), .y(y), .z(z_a1));
  A a2(.x(x), .y(y), .z(z_a2));
  B b1(.x(x), .y(y), .z(z_b1));
  B b2(.x(x), .y(y), .z(z_b2));
  wire or_out = z_a1 | z_b1;
  wire and_out = z_a2 & z_b2;
  assign z = or_out ^ and_out;
endmodule