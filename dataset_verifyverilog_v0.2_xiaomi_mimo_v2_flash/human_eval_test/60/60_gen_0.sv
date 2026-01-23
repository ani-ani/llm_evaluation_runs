module sum_to_n (
    input [6:0] n,
    output [15:0] result
);

    // Intermediate product: n * (n + 1)
    // n is max 100 (7 bits), n+1 is max 101 (7 bits).
    // Product max is 10100, which fits in 14 bits.
    // Output is 16 bits to match requirement.
    wire [13:0] product;
    
    assign product = n * (n + 1);
    
    // Division by 2
    assign result = {2'b00, product[13:1]};

endmodule