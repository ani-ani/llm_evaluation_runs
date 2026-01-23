module add_even_at_odd_indices (
    input [7:0] arr [0:7],
    output [15:0] result
);

    wire signed [15:0] sum1;
    wire signed [15:0] sum2;
    wire signed [15:0] sum3;
    wire signed [15:0] sum4;

    // Check index 1 (odd)
    assign sum1 = (arr[1][0] == 1'b0) ? {8'b0, arr[1]} : 16'sd0;

    // Check index 3 (odd)
    assign sum2 = (arr[3][0] == 1'b0) ? {8'b0, arr[3]} : 16'sd0;

    // Check index 5 (odd)
    assign sum3 = (arr[5][0] == 1'b0) ? {8'b0, arr[5]} : 16'sd0;

    // Check index 7 (odd)
    assign sum4 = (arr[7][0] == 1'b0) ? {8'b0, arr[7]} : 16'sd0;

    // Sum the values
    assign result = sum1 + sum2 + sum3 + sum4;

endmodule
