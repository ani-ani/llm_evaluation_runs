module max_of_nth (
  input [1:0] column_index,
  input [2:0][2:0][7:0] matrix,
  output [7:0] max_value
);

  wire [7:0] col0_val = matrix[0][column_index];
  wire [7:0] col1_val = matrix[1][column_index];
  wire [7:0] col2_val = matrix[2][column_index];

  wire [7:0] max01 = (col0_val > col1_val) ? col0_val : col1_val;
  assign max_value = (max01 > col2_val) ? max01 : col2_val;

endmodule