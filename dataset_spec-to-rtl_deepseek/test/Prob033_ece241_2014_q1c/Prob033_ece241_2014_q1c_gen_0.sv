module TopModule(
    input [7:0] a,
    input [7:0] b,
    output [7:0] s,
    output overflow
);
    wire signed [7:0] as = a;
    wire signed [7:0] bs = b;
    assign s = as + bs;
    assign overflow = (a[7] == b[7]) && (s[7] != a[7]);
endmodule