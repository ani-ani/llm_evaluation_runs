module matrix_sort_by_row_sum(
  input [7:0] matrix [0:2][0:2],
  output [7:0] sorted_matrix [0:2][0:2]
);

  // Compute row sums (10-bit signed)
  wire [9:0] sum [0:2];
  assign sum[0] = matrix[0][0] + matrix[0][1] + matrix[0][2];
  assign sum[1] = matrix[1][0] + matrix[1][1] + matrix[1][2];
  assign sum[2] = matrix[2][0] + matrix[2][1] + matrix[2][2];

  // Bubble sort stage 1
  wire [1:0] stage1 [0:2];
  assign stage1[0] = (sum[0] < sum[1]) ? 0 : 1;
  assign stage1[1] = (sum[1] < sum[2]) ? 1 : 2;
  assign stage1[2] = (sum[0] < sum[2]) ? 0 : 2;

  // Bubble sort stage 2
  wire [1:0] sorted_indices [0:2];
  assign sorted_indices[0] = (stage1[0] < stage1[1]) ? stage1[0] : stage1[1];
  assign sorted_indices[1] = (stage1[0] < stage1[1]) ? stage1[1] : stage1[0];
  assign sorted_indices[2] = stage1[2];

  // Final index assignment
  wire [1:0] final_indices [0:2];
  assign final_indices[0] = (sorted_indices[0] < sorted_indices[1]) ? sorted_indices[0] : sorted_indices[1];
  assign final_indices[1] = (sorted_indices[0] < sorted_indices[1]) ? sorted_indices[1] : sorted_indices[0];
  assign final_indices[2] = sorted_indices[2];

  // Output matrix with sorted rows
  assign sorted_matrix[0] = (final_indices[0] == 0) ? matrix[0] : 
                            (final_indices[0] == 1) ? matrix[1] : matrix[2];
  assign sorted_matrix[1] = (final_indices[1] == 0) ? matrix[0] : 
                            (final_indices[1] == 1) ? matrix[1] : matrix[2];
  assign sorted_matrix[2] = (final_indices[2] == 0) ? matrix[0] : 
                            (final_indices[2] == 1) ? matrix[1] : matrix[2];

endmodule