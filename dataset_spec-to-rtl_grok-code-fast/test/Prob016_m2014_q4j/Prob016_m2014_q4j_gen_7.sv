module TopModule(
    input [3:0] x,
    input [3:0] y,
    output [4:0] sum
);

    wire [3:0] s;
    wire [4:0] c;
    
    assign c[0] = 1'b0;
    
    generate
        for (genvar i = 0; i < 4; i = i + 1) begin : gen_fa
            full_adder fa(
                .a(x[i]), 
                .b(y[i]), 
                .cin(c[i]), 
                .s(s[i]), 
                .cout(c[i+1])
            );
        end
    endgenerate
    
    assign sum = {c[4], s};

endmodule

module full_adder(
    input a,
    input b,
    input cin,
    output s,
    output cout
);
    assign s = a ^ b ^ cin;
    assign cout = (a & b) | (cin & (a ^ b));
endmodule