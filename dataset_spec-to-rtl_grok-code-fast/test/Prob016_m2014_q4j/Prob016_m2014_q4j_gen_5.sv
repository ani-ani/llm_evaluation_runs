module TopModule(
  input [3:0] x,
  input [3:0] y,
  output [4:0] sum
);

  wire c1, c2, c3, c4;

  // Full Adder module definition
  module FullAdder(
    input a, b, cin,
    output cout, s
  );
    assign s = a ^ b ^ cin;
    assign cout = (a & b) | (a & cin) | (b & cin);
  endmodule

  FullAdder FA0(.a(x[0]), .b(y[0]), .cin(1'b0), .cout(c1), .s(sum[0]));
  FullAdder FA1(.a(x[1]), .b(y[1]), .cin(c1), .cout(c2), .s(sum[1]));
  FullAdder FA2(.a(x[2]), .b(y[2]), .cin(c2), .cout(c3), .s(sum[2]));
  FullAdder FA3(.a(x[3]), .b(y[3]), .cin(c3), .cout(c4), .s(sum[3]));

  assign sum[4] = c4;

endmodule