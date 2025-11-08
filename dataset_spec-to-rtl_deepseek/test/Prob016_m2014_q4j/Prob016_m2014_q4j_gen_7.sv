module TopModule(
  input reg [3:0] x,
  input reg [3:0] y,
  output [4:0] sum
);

  wire c1, c2, c3;

  full_adder fa0(.a(x[0]), .b(y[0]), .ci(1'b0), .sum(sum[0]), .co(c1));
  full_adder fa1(.a(x[1]), .b(y[1]), .ci(c1), .sum(sum[1]), .co(c2));
  full_adder fa2(.a(x[2]), .b(y[2]), .ci(c2), .sum(sum[2]), .co(c3));
  full_adder fa3(.a(x[3]), .b(y[3]), .ci(c3), .sum(sum[3]), .co(sum[4]));

  module full_adder(input a, b, ci, output sum, co);
    assign sum = a ^ b ^ ci;
    assign co = (a & b) | (ci & (a | b));
  endmodule

endmodule