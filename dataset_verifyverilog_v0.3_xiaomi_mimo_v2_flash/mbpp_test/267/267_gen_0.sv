module SquareSumOdd (
    input [7:0] n,
    output reg [23:0] result
);

    // Internal signals for intermediate calculations
    reg [15:0] n_sq;          // n*n max: 16*16 = 256 (8-bit)
    reg [17:0] four_n_sq;     // 4*n*n max: 1024 (10-bit)
    reg [17:0] four_n_sq_minus_1;  // 4*n*n - 1 (10-bit)
    reg [25:0] numerator;     // n*(4*n*n-1) max: 16*1023 = 16368 (14-bit, but 25 to be safe)
    reg [23:0] division_result;  // Final result (24-bit)
    
    // Combinational logic
    always @(*) begin
        // Step 1: n*n
        n_sq = n * n;
        
        // Step 2: 4*n*n
        four_n_sq = n_sq << 2;
        
        // Step 3: 4*n*n - 1
        four_n_sq_minus_1 = four_n_sq - 18'd1;
        
        // Step 4: n*(4*n*n - 1)
        numerator = n * four_n_sq_minus_1;
        
        // Step 5: divide by 3 using integer division (floor)
        division_result = numerator / 3'd3;
        
        // Output
        result = division_result;
    end

endmodule