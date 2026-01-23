module matrix_sort_by_row_sum(input signed [7:0] matrix [0:2][0:2], output signed [7:0] sorted_matrix [0:2][0:2]);
wire signed [9:0] sum [0:2];
wire swap01, swap12_cond;
wire [1:0] stage1_idx0, stage1_idx1, stage1_idx2;
wire swap20, swap21_cond;
wire [1:0] final_idx0, final_idx1, final_idx2;

assign sum[0] = matrix[0][0] + matrix[0][1] + matrix[0][2];
assign sum[1] = matrix[1][0] + matrix[1][1] + matrix[1][2];
assign sum[2] = matrix[2][0] + matrix[2][1] + matrix[2][2];

assign swap01 = (sum[0] > sum[1]);
assign swap12_cond = (swap01 && (sum[0] > sum[2])) || (!swap01 && (sum[1] > sum[2]));

assign stage1_idx0 = swap01 ? 2'b01 : 2'b00;
assign stage1_idx1 = swap01 ? (swap12_cond ? 2'b10 : 2'b00) : (swap12_cond ? 2'b10 : 2'b01);
assign stage1_idx2 = swap01 ? (swap12_cond ? 2'b00 : 2'b10) : (swap12_cond ? 2'b01 : 2'b10);

assign swap20 = (sum[stage1_idx0] > sum[stage1_idx1]);
assign swap21_cond = (swap20 && (sum[stage1_idx0] > sum[stage1_idx2])) || (!swap20 && (sum[stage1_idx1] > sum[stage1_idx2]));

assign final_idx0 = swap20 ? stage1_idx1 : stage1_idx0;
assign final_idx1 = swap20 ? (swap21_cond ? stage1_idx2 : stage1_idx0) : (swap21_cond ? stage1_idx2 : stage1_idx1);
assign final_idx2 = swap20 ? (swap21_cond ? stage1_idx0 : stage1_idx2) : (swap21_cond ? stage1_idx1 : stage1_idx2);

assign sorted_matrix[0][0] = (final_idx0 == 2'b00) ? matrix[0][0] : ( (final_idx0 == 2'b01) ? matrix[1][0] : matrix[2][0] );
assign sorted_matrix[0][1] = (final_idx0 == 2'b00) ? matrix[0][1] : ( (final_idx0 == 2'b01) ? matrix[1][1] : matrix[2][1] );
assign sorted_matrix[0][2] = (final_idx0 == 2'b00) ? matrix[0][2] : ( (final_idx0 == 2'b01) ? matrix[1][2] : matrix[2][2] );

assign sorted_matrix[1][0] = (final_idx1 == 2'b00) ? matrix[0][0] : ( (final_idx1 == 2'b01) ? matrix[1][0] : matrix[2][0] );
assign sorted_matrix[1][1] = (final_idx1 == 2'b00) ? matrix[0][1] : ( (final_idx1 == 2'b01) ? matrix[1][1] : matrix[2][1] );
assign sorted_matrix[1][2] = (final_idx1 == 2'b00) ? matrix[0][2] : ( (final_idx1 == 2'b01) ? matrix[1][2] : matrix[2][2] );

assign sorted_matrix[2][0] = (final_idx2 == 2'b00) ? matrix[0][0] : ( (final_idx2 == 2'b01) ? matrix[1][0] : matrix[2][0] );
assign sorted_matrix[2][1] = (final_idx2 == 2'b00) ? matrix[0][1] : ( (final_idx2 == 2'b01) ? matrix[1][1] : matrix[2][1] );
assign sorted_matrix[2][2] = (final_idx2 == 2'b00) ? matrix[0][2] : ( (final_idx2 == 2'b01) ? matrix[1][2] : matrix[2][2] );

endmodule