module full_adder(
    input a, b, cin,
    output sum, cout
);
    assign sum = a ^ b ^ cin;
    assign cout = (a & b) | (cin & (a ^ b));
endmodule

module TopModule(
    input reg [3:0] x,
    input reg [3:0] y,
    output [4:0] sum
);
    wire carry0, carry1, carry2;
    
    full_adder fa0(.a(x[0]), .b(y[0]), .cin(1'b0), .sum(sum[0]), .cout(carry0));
    full_adder fa1(.a(x[1]), .b(y[1]), .cin(carry0), .sum(sum[1]), .cout(carry1));
    full_adder fa2(.a(x[2]), .b(y[2]), .cin(carry1), .sum(sum[2]), .cout(carry2));
    full_adder fa3(.a(x[3]), .b(y[3]), .cin(carry2), .sum(sum[3]), .cout(sum[4]));
endmodule