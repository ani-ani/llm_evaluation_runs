module TopModule(
    input reg clock,
    input reg a,
    output reg p,
    output reg q
);
    always @(posedge clock) p <= a;
    always @(negedge clock) q <= p;
endmodule