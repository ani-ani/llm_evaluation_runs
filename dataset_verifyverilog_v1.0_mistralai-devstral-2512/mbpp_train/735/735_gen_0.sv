module toggle_middle_bits(
    input [15:0] n,
    output [15:0] result,
    output done
);
    
    wire [15:0] mask;
    wire [15:0] shifted_n;
    
    // Compute mask via OR-shifts
    wire [15:0] or1 = n | (n >> 1);
    wire [15:0] or2 = or1 | (or1 >> 2);
    wire [15:0] or3 = or2 | (or2 >> 4);
    wire [15:0] or4 = or3 | (or3 >> 8);
    wire [15:0] or5 = or4 | (or4 >> 16);
    
    assign shifted_n = or5 >> 1;
    assign mask = shifted_n ^ 16'd1;
    
    // Special case: n == 1
    assign result = (n == 16'd1) ? 16'd1 : (n ^ mask);
    assign done = 1'b1;
    
endmodule