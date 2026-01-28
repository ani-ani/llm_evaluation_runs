module hexagon_triangles (
    input [9:0] a1, a2, a3, a4, a5, a6,
    output [23:0] result
);
    // Combinational logic to compute number of unit triangles
    // Formula: (a1 + a2 + a3)^2 - a1^2 - a3^2 - a5^2
    wire [31:0] sum;
    wire [31:0] sum_sq;
    wire [31:0] a1_sq, a3_sq, a5_sq;
    
    assign sum = a1 + a2 + a3;
    assign sum_sq = sum * sum;
    assign a1_sq = a1 * a1;
    assign a3_sq = a3 * a3;
    assign a5_sq = a5 * a5;
    
    assign result = sum_sq - a1_sq - a3_sq - a5_sq;
endmodule