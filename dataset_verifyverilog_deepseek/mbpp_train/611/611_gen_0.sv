module max_nth_column(
  input [2:0][4:0] row0, row1, row2,
  input [1:0] col_idx,
  output [4:0] max_val
);
  
  wire [4:0] col0 = row0[col_idx];
  wire [4:0] col1 = row1[col_idx];
  wire [4:0] col2 = row2[col_idx];
  
  assign max_val = (col0 >= col1 && col0 >= col2) ? col0 :
                   (col1 >= col2) ? col1 : col2;
  
endmodule