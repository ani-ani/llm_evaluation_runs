module BitRangeUnsetChecker(
    input [15:0] n,
    input [7:0] l,
    input [7:0] r,
    output result
);
    wire [15:0] mask;
    wire [15:0] masked_n;
    
    assign mask = ((1 << r) - 1) ^ ((1 << (l - 1)) - 1);
    assign masked_n = n & mask;
    assign result = (masked_n == 0);
endmodule