module full_adder(input a, input b, input cin, output sum, output cout);
  assign sum = a ^ b ^ cin;
  assign cout = (a & b) | (a & cin) | (b & cin);
endmodule

module TopModule(
  input reg [3:0] x,
  input reg [3:0] y,
  output reg [4:0] sum
);
  wire c1, c2, c3, cout;
  wire s0, s1, s2, s3;

  full_adder fa0(.a(x[0]), .b(y[0]), .cin(1'b0), .sum(s0), .cout(c1));
  full_adder fa1(.a(x[1]), .b(y[1]), .cin(c1), .sum(s1), .cout(c2));
  full_adder fa2(.a(x[2]), .b(y[2]), .cin(c2), .sum(s2), .cout(c3));
  full_adder fa3(.a(x[3]), .b(y[3]), .cin(c3), .sum(s3), .cout(cout));

  always @* sum = {cout, s3, s2, s1, s0};
endmodule