module TopModule(input [3:0] x, input [3:0] y, output [4:0] sum);

  wire [3:0] carries;
  assign carries[0] = 1'b0;

  // Full Adder instances
  fullAdder FA0(.a(x[0]), .b(y[0]), .cin(carries[0]), .s(sum[0]), .cout(carries[1]));
  fullAdder FA1(.a(x[1]), .b(y[1]), .cin(carries[1]), .s(sum[1]), .cout(carries[2]));
  fullAdder FA2(.a(x[2]), .b(y[2]), .cin(carries[2]), .s(sum[2]), .cout(carries[3]));
  fullAdder FA3(.a(x[3]), .b(y[3]), .cin(carries[3]), .s(sum[3]), .cout(sum[4]));

endmodule

// Full Adder module
module fullAdder(input a, input b, input cin, output s, output cout);
  assign s = a ^ b ^ cin;
  assign cout = (a & b) | (b & cin) | (cin & a);
endmodule