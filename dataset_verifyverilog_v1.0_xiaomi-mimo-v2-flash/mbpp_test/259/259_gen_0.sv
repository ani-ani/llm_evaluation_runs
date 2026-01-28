module maximize_matrix (
    input wire [3:0] matrix1 [0:3][0:1],
    input wire [3:0] matrix2 [0:3][0:1],
    output wire [3:0] result [0:3][0:1]
);
    // Row 0, Col 0
    assign result[0][0] = (matrix1[0][0] > matrix2[0][0]) ? matrix1[0][0] : matrix2[0][0];
    // Row 0, Col 1
    assign result[0][1] = (matrix1[0][1] > matrix2[0][1]) ? matrix1[0][1] : matrix2[0][1];
    // Row 1, Col 0
    assign result[1][0] = (matrix1[1][0] > matrix2[1][0]) ? matrix1[1][0] : matrix2[1][0];
    // Row 1, Col 1
    assign result[1][1] = (matrix1[1][1] > matrix2[1][1]) ? matrix1[1][1] : matrix2[1][1];
    // Row 2, Col 0
    assign result[2][0] = (matrix1[2][0] > matrix2[2][0]) ? matrix1[2][0] : matrix2[2][0];
    // Row 2, Col 1
    assign result[2][1] = (matrix1[2][1] > matrix2[2][1]) ? matrix1[2][1] : matrix2[2][1];
    // Row 3, Col 0
    assign result[3][0] = (matrix1[3][0] > matrix2[3][0]) ? matrix1[3][0] : matrix2[3][0];
    // Row 3, Col 1
    assign result[3][1] = (matrix1[3][1] > matrix2[3][1]) ? matrix1[3][1] : matrix2[3][1];
endmodule