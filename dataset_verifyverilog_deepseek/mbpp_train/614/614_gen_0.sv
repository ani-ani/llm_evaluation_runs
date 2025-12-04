module tuple_list_sum (
  input [2:0] valid_matrix [0:2][0:2],
  input [7:0] data_matrix [0:2][0:2],
  output logic [11:0] total_sum
);

  wire [11:0] contributions [0:2][0:2];

  generate
    for (genvar i = 0; i < 3; i++) begin
      for (genvar j = 0; j < 3; j++) begin
        assign contributions[i][j] = valid_matrix[i][2-j] ? {4'b0, data_matrix[i][j]} : 12'b0;
      end
    end
  endgenerate

  assign total_sum = contributions[0][0] + contributions[0][1] + contributions[0][2] +
                     contributions[1][0] + contributions[1][1] + contributions[1][2] +
                     contributions[2][0] + contributions[2][1] + contributions[2][2];

endmodule