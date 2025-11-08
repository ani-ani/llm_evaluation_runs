module TopModule(
    output reg [4:0] sum,
    input reg [3:0] x,
    input reg [3:0] y
);
    wire c_out1, c_out2, c_out3, c_out4;
    wire s0, s1, s2, s3;
    
    full_adder fa0 (.a(x[0]), .b(y[0]), .cin(1'b0), .sum(s0), .cout(c_out1));
    full_adder fa1 (.a(x[1]), .b(y[1]), .cin(c_out1), .sum(s1), .cout(c_out2));
    full_adder fa2 (.a(x[2]), .b(y[2]), .cin(c_out2), .sum(s2), .cout(c_out3));
    full_adder fa3 (.a(x[3]), .b(y[3]), .cin(c_out3), .sum(s3), .cout(c_out4));
    
    assign sum = {c_out4, s3, s2, s1, s0};
    
    module full_adder(
        input a,
        input b,
        input cin,
        output sum,
        output cout
    );
        assign sum = a ^ b ^ cin;
        assign cout = (a & b) | (cin & (a ^ b));
    endmodule
    
endmodule