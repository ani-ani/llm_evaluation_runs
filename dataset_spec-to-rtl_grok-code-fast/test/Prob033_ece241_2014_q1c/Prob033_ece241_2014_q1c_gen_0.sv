module TopModule(
    input logic [7:0] a,
    input logic [7:0] b,
    output logic [7:0] s,
    output logic overflow
);
    logic signed [7:0] sa = signed'(a);
    logic signed [7:0] sb = signed'(b);
    logic signed [7:0] ss;

    assign ss = sa + sb;
    assign s = ss;
    assign overflow = ((sa[7] & sb[7] & ~ss[7]) | (~sa[7] & ~sb[7] & ss[7]));
endmodule