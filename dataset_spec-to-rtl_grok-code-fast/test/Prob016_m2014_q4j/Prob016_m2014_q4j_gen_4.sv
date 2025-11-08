module FullAdder(
    input a,
    input b,
    input cin,
    output sum,
    output cout
);
    assign {cout, sum} = a + b + cin;
endmodule

module TopModule(
    input [3:0] x,
    input [3:0] y,
    output [4:0] sum
);
    wire [3:0] carries;
    FullAdder fa0(.a(x[0]), .b(y[0]), .cin(1'b0), .sum(sum[0]), .cout(carries[0]));
    FullAdder fa1(.a(x[1]), .b(y[1]), .cin(carries[0]), .sum(sum[1]), .cout(carries[1]));
    FullAdder fa2(.a(x[2]), .b(y[2]), .cin(carries[1]), .sum(sum[2]), .cout(carries[2]));
    FullAdder fa3(.a(x[3]), .b(y[3]), .cin(carries[2]), .sum(sum[3]), .cout(sum[4]));
endmodule