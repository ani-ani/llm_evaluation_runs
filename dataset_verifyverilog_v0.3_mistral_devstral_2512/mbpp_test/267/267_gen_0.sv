module SquareSumOdd(
    input [7:0] n,
    output [23:0] result
);
    
    // Intermediate signals for the formula: n*(4*n*n-1)/3
    wire [23:0] n_squared;
    wire [25:0] four_n_squared;
    wire [25:0] four_n_squared_minus_one;
    wire [25:0] n_times_four_n_squared_minus_one;
    wire [23:0] result_divided_by_three;
    
    // Calculate n squared
    assign n_squared = n * n;
    
    // Calculate 4*n*n
    assign four_n_squared = 4'd4 * n_squared;
    
    // Calculate 4*n*n - 1
    assign four_n_squared_minus_one = four_n_squared - 25'd1;
    
    // Calculate n*(4*n*n - 1)
    assign n_times_four_n_squared_minus_one = n * four_n_squared_minus_one;
    
    // Calculate n*(4*n*n - 1)/3 using integer division
    assign result_divided_by_three = n_times_four_n_squared_minus_one / 3'd3;
    
    // Assign the final result
    assign result = result_divided_by_three;
    
endmodule