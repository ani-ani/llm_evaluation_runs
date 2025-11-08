module fulladd(input a, input b, input cin, output s, output cout);
  assign s = a ^ b ^ cin;
  assign cout = (a & b) | (b & cin) | (a & cin);
endmodule

module TopModule(input [3:0] x, input [3:0] y, output [4:0] sum);
  wire [3:0] cout;
  wire cin0 = 0;
  fulladd fa0(.a(x[0]), .b(y[0]), .cin(cin0), .s(sum[0]), .cout(cout[0]));
  fulladd fa1(.a(x[1]), .b(y[1]), .cin(cout[0]), .s(sum[1]), .cout(cout[1]));
  fulladd fa2(.a(x[2]), .b(y[2]), .cin(cout[1]), .s(sum[2]), .cout(cout[2]));
  fulladd fa3(.a(x[3]), .b(y[3]), .cin(cout[2]), .s(sum[3]), .cout(cout[3]));
  assign sum[4] = cout[3];
endmodule