module sum_even_even_pos(
    input [7:0] arr [0:7],
    output [15:0] sum
);

    // Combinational logic to sum even numbers at even indices
    // Indices 0, 2, 4, 6 are even positions
    // Check if value is even (arr[i][0] == 0)
    
    wire [15:0] sum0 = (arr[0][0] == 1'b0) ? {8'b0, arr[0]} : 16'd0;
    wire [15:0] sum2 = (arr[2][0] == 1'b0) ? {8'b0, arr[2]} : 16'd0;
    wire [15:0] sum4 = (arr[4][0] == 1'b0) ? {8'b0, arr[4]} : 16'd0;
    wire [15:0] sum6 = (arr[6][0] == 1'b0) ? {8'b0, arr[6]} : 16'd0;
    
    assign sum = sum0 + sum2 + sum4 + sum6;

endmodule