module tuple_list_sum(
  input  [2:0]  valid_matrix [0:2][0:2],
  input  [7:0]  data_matrix  [0:2][0:2],
  output [11:0] total_sum
);

  wire [11:0] sum00 = valid_matrix[0][0] ? data_matrix[0][0] : 12'd0;
  wire [11:0] sum01 = valid_matrix[0][1] ? data_matrix[0][1] : 12'd0;
  wire [11:0] sum02 = valid_matrix[0][2] ? data_matrix[0][2] : 12'd0;

  wire [11:0] sum10 = valid_matrix[1][0] ? data_matrix[1][0] : 12'd0;
  wire [11:0] sum11 = valid_matrix[1][1] ? data_matrix[1][1] : 12'd0;
  wire [11:0] sum12 = valid_matrix[1][2] ? data_matrix[1][2] : 12'd0;

  wire [11:0] sum20 = valid_matrix[2][0] ? data_matrix[2][0] : 12'd0;
  wire [11:0] sum21 = valid_matrix[2][1] ? data_matrix[2][1] : 12'd0;
  wire [11:0] sum22 = valid_matrix[2][2] ? data_matrix[2][2] : 12'd0;

  assign total_sum = sum00 + sum01 + sum02 +
                     sum10 + sum11 + sum12 +
                     sum20 + sum21 + sum22;

endmodule