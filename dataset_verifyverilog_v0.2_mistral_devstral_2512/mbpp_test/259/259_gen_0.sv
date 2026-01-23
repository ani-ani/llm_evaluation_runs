module maximize_2d_array(
  input [7:0] array1 [0:3][0:1],
  input [7:0] array2 [0:3][0:1],
  output [7:0] result [0:3][0:1]
);

  // Element-wise maximization for each position in the 4x2 array
  genvar i, j;
  generate
    for (i = 0; i < 4; i = i + 1) begin : ROWS
      for (j = 0; j < 2; j = j + 1) begin : COLS
        assign result[i][j] = (array1[i][j] > array2[i][j]) ? array1[i][j] : array2[i][j];
      end
    end
  endgenerate

endmodule