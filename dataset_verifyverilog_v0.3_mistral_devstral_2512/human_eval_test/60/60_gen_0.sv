module sum_to_n(
    input [15:0] n,
    output [31:0] result
);
    
    // Compute n*(n+1)/2 using arithmetic operations
    wire [16:0] n_plus_1 = n + 16'd1;
    wire [31:0] product = n * n_plus_1;
    assign result = product / 2;
    
endmodule