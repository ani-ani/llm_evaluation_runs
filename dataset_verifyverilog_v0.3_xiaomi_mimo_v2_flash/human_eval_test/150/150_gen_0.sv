module x_or_y(
    input [7:0] n,
    input [7:0] x,
    input [7:0] y,
    output [7:0] result
);
    // Prime check for numbers 0-255 using combinational logic
    wire is_prime;
    wire is_prime_temp;
    
    // Check if n is 2 (special case - only even prime)
    wire is_two;
    assign is_two = (n == 8'd2);
    
    // Check if n is even (and not 2)
    wire is_even;
    assign is_even = ~n[0]; // n[0] = 0 means even
    
    // Check if n is 0 or 1
    wire is_zero_or_one;
    assign is_zero_or_one = (n == 8'd0) || (n == 8'd1);
    
    // For odd numbers > 2, check divisibility by primes up to 15
    wire is_divisible_by_3;
    wire is_divisible_by_5;
    wire is_divisible_by_7;
    wire is_divisible_by_11;
    wire is_divisible_by_13;
    
    // Check divisibility using multiplication
    // n % d == 0 means (n/d) * d == n
    // For synthesizable combinational logic, we compute n % d using remainder calculation
    
    // Division approach: compute n / d and multiply back
    wire [7:0] q3, q5, q7, q11, q13;
    wire [7:0] r3, r5, r7, r11, r13;
    
    // Division by 3 (unsigned)
    // For small divisors, we can use integer division
    assign q3 = n / 8'd3;
    assign r3 = n % 8'd3;
    assign is_divisible_by_3 = (r3 == 8'd0) && (n > 8'd3);
    
    // Division by 5
    assign q5 = n / 8'd5;
    assign r5 = n % 8'd5;
    assign is_divisible_by_5 = (r5 == 8'd0) && (n > 8'd5);
    
    // Division by 7
    assign q7 = n / 8'd7;
    assign r7 = n % 8'd7;
    assign is_divisible_by_7 = (r7 == 8'd0) && (n > 8'd7);
    
    // Division by 11
    assign q11 = n / 8'd11;
    assign r11 = n % 8'd11;
    assign is_divisible_by_11 = (r11 == 8'd0) && (n > 8'd11);
    
    // Division by 13
    assign q13 = n / 8'd13;
    assign r13 = n % 8'd13;
    assign is_divisible_by_13 = (r13 == 8'd0) && (n > 8'd13);
    
    // Determine if n is prime
    // n is prime if:
    // - n is 2, OR
    // - n is odd AND > 2 AND not divisible by any of 3, 5, 7, 11, 13
    assign is_prime = is_two || 
                      (~is_zero_or_one && ~is_even && 
                       ~is_divisible_by_3 && ~is_divisible_by_5 && 
                       ~is_divisible_by_7 && ~is_divisible_by_11 && 
                       ~is_divisible_by_13);
    
    // Multiplexer: return x if prime, y otherwise
    assign result = is_prime ? x : y;
    
endmodule