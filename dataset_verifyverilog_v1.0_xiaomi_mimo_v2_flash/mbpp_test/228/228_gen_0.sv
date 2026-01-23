module BitRangeUnsetChecker(
    input [15:0] n,
    input [7:0] l,
    input [7:0] r,
    output result
);

    // Generate mask with 1s in positions l through r (inclusive)
    // mask = ((1<<r) - 1) ^ ((1<<(l-1)) - 1)
    wire [15:0] mask;
    wire [15:0] temp_r;
    wire [15:0] temp_l;
    
    assign temp_r = (16'd1 << r) - 16'd1;
    assign temp_l = (16'd1 << (l - 16'd1)) - 16'd1;
    assign mask = temp_r ^ temp_l;
    
    // Check if all bits in range are 0
    assign result = ((n & mask) == 16'd0) ? 1'b1 : 1'b0;

endmodule