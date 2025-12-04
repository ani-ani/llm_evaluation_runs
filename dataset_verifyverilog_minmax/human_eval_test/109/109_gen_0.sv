module adder (input [7:0] a, b, input cin, output [8:0] sum, output cout);
  assign {cout, sum} = a + b + cin;
endmodule