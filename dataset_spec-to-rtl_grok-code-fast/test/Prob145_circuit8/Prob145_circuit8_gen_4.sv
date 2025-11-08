module TopModule(
    input clock,
    input a,
    output p,
    output q
);
    always @(negedge clock) q <= ~q;
    assign p = clock ? a : q;
endmodule