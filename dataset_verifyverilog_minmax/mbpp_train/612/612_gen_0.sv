module array_transposer (
  input [3:0][3:0][7:0] arr_in,
  output [3:0][3:0][7:0] arr_out
);

  genvar i, j;
  generate
    for (i = 0; i < 4; i++) begin : transpose_rows
      for (j = 0; j < 4; j++) begin : transpose_cols
        assign arr_out[i][j] = arr_in[j][i];
      end
    end
  endgenerate

endmodule