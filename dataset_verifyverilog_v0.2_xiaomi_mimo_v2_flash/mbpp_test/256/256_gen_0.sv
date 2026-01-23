module prime_counter (
    input [3:0] n,
    output reg [3:0] count
);

    always @(*) begin
        count = 4'b0;
        
        if (n > 4'd2) count = count + 1'b1;
        if (n > 4'd3) count = count + 1'b1;
        if (n > 4'd5) count = count + 1'b1;
        if (n > 4'd7) count = count + 1'b1;
        if (n > 4'd11) count = count + 1'b1;
        if (n > 4'd13) count = count + 1'b1;
    end

endmodule

module prime_counter_orig (
    input [3:0] n,
    output reg [3:0] count
);

    // Generate prime flags for numbers 0-15
    // 2, 3, 5, 7, 11, 13 are prime
    always @(*) begin
        count = 4'b0;
        
        // For each prime k, check if k < n and accumulate
        // Since we only have 6 primes, we can unroll this
        // Primes are: 2, 3, 5, 7, 11, 13
        
        // k=2 is prime: contribute if n > 2
        if (n > 4'd2) count = count + 1'b1;
        
        // k=3 is prime: contribute if n > 3
        if (n > 4'd3) count = count + 1'b1;
        
        // k=5 is prime: contribute if n > 5
        if (n > 4'd5) count = count + 1'b1;
        
        // k=7 is prime: contribute if n > 7
        if (n > 4'd7) count = count + 1'b1;
        
        // k=11 is prime: contribute if n > 11
        if (n > 4'd11) count = count + 1'b1;
        
        // k=13 is prime: contribute if n > 13
        if (n > 4'd13) count = count + 1'b1;
    end

endmodule
