module x_or_y(
    input [7:0] n,
    input [7:0] x,
    input [7:0] y,
    output [7:0] result
);
    
    reg is_prime;
    
    // Check if n is 0 or 1 (not prime)
    assign is_prime = (n != 8'd0) && (n != 8'd1);
    
    // Check if n is 2 (prime)
    assign is_prime = is_prime && ((n == 8'd2) || (n != 8'd2));
    
    // Check if n is even and greater than 2 (not prime)
    assign is_prime = is_prime && !((n > 8'd2) && (n[0] == 1'b0));
    
    // Check divisibility by odd numbers for n > 2
    reg [7:0] i;
    reg divisible;
    
    always @(*) begin
        divisible = 1'b0;
        if (n > 8'd2) begin
            for (i = 8'd3; i <= 8'd15; i = i + 8'd2) begin
                if (i * i > n) begin
                    break;
                end
                if (n % i == 8'd0) begin
                    divisible = 1'b1;
                end
            end
        end
    end
    
    assign is_prime = is_prime && !divisible;
    
    // Multiplexer logic
    assign result = is_prime ? x : y;
    
endmodule