module BitRangeUnsetChecker (
    input [15:0] n,
    input [7:0] l,
    input [7:0] r,
    output result
);
    wire [15:0] mask;
    wire [15:0] temp1 = (16'd1 << r) - 16'd1;
    wire [15:0] temp2 = (16'd1 << (l - 8'd1)) - 16'd1;
    assign mask = temp1 ^ temp2;
    assign result = (n & mask) == 16'd0 ? 1 : 0;
endmodule