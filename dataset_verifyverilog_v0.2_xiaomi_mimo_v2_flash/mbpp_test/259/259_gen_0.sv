module maximize_2d_array (
    input [7:0] array1 [0:3][0:1],
    input [7:0] array2 [0:3][0:1],
    output logic [7:0] result [0:3][0:1]
);

    // Combinational element-wise maximization
    assign result[0][0] = (array1[0][0] > array2[0][0]) ? array1[0][0] : array2[0][0];
    assign result[0][1] = (array1[0][1] > array2[0][1]) ? array1[0][1] : array2[0][1];
    assign result[1][0] = (array1[1][0] > array2[1][0]) ? array1[1][0] : array2[1][0];
    assign result[1][1] = (array1[1][1] > array2[1][1]) ? array1[1][1] : array2[1][1];
    assign result[2][0] = (array1[2][0] > array2[2][0]) ? array1[2][0] : array2[2][0];
    assign result[2][1] = (array1[2][1] > array2[2][1]) ? array1[2][1] : array2[2][1];
    assign result[3][0] = (array1[3][0] > array2[3][0]) ? array1[3][0] : array2[3][0];
    assign result[3][1] = (array1[3][1] > array2[3][1]) ? array1[3][1] : array2[3][1];

endmodule