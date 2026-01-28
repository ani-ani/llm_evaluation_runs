module median3(
    input [7:0] a,
    input [7:0] b,
    input [7:0] c,
    output reg [7:0] median
);

    // Internal comparison results
    reg a_ge_b;
    reg a_ge_c;
    reg b_ge_c;

    // Always block for combinational logic
    always @(*) begin
        // Compare all pairs (unsigned)
        a_ge_b = (a >= b);
        a_ge_c = (a >= c);
        b_ge_c = (b >= c);

        // Determine median based on comparison results
        // There are 6 possible orderings of 3 values
        // We use the comparison flags to select the middle one
        
        // Truth table approach:
        // If a is median: a >= b && a <= c OR a <= b && a >= c
        // If b is median: b >= a && b <= c OR b <= a && b >= c  
        // If c is median: c >= a && c <= b OR c <= a && c >= b
        
        // More efficient: use the fact that median is the value
        // that is neither the max nor the min
        
        if ((a >= b && a >= c) || (a <= b && a <= c)) begin
            // a is either max or min, so median is between b and c
            if ((b >= a && b >= c) || (b <= a && b <= c)) begin
                // b is also extreme, so c must be median
                median = c;
            end else begin
                // b is median (not extreme)
                median = b;
            end
        end else begin
            // a is median (not extreme)
            median = a;
        end
    end

endmodule