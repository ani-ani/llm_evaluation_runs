module max_nth_column(
  input  [2:0][4:0] row0,
  input  [2:0][4:0] row1,
  input  [2:0][4:0] row2,
  input  [1:0]      col_idx,
  output [4:0]      max_val
);

  wire [4:0] col0_val;
  wire [4:0] col1_val;
  wire [4:0] col2_val;

  assign col0_val = (col_idx == 2'd0) ? row0[0] :
                    (col_idx == 2'd1) ? row0[1] :
                    (col_idx == 2'd2) ? row0[2] : 5'd0;

  assign col1_val = (col_idx == 2'd0) ? row1[0] :
                    (col_idx == 2'd1) ? row1[1] :
                    (col_idx == 2'd2) ? row1[2] : 5'd0;

  assign col2_val = (col_idx == 2'd0) ? row2[0] :
                    (col_idx == 2'd1) ? row2[1] :
                    (col_idx == 2'd2) ? row2[2] : 5'd0;

  assign max_val = (col0_val >= col1_val) ?
                     ((col0_val >= col2_val) ? col0_val : col2_val) :
                     ((col1_val >= col2_val) ? col1_val : col2_val);

endmodule