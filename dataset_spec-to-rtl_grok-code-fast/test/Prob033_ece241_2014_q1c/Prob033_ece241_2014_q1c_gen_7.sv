module TopModule (
    input [7:0] a,
    input [7:0] b,
    output [7:0] s,
    output overflow
);
    wire signed [7:0] signed_a = a;
    wire signed [7:0] signed_b = b;
    wire signed [7:0] signed_s;
    assign signed_s = signed_a + signed_b;
    assign s = signed_s;
    assign overflow = (signed_a[7] == signed_b[7]) && (signed_s[7] != signed_a[7]);
endmodule