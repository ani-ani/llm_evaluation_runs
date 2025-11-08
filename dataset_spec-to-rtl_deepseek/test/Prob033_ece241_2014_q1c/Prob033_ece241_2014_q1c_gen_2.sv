module TopModule(
    input [7:0] a,
    input [7:0] b,
    output [7:0] s,
    output overflow
);
    logic signed [7:0] sa, sb;
    assign sa = a;
    assign sb = b;
    assign s = sa + sb;
    assign overflow = (sa[7] == sb[7]) && (sa[7] != s[7]);
endmodule