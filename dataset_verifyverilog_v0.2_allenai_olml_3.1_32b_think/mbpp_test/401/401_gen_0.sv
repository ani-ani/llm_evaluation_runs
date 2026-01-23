module matrix_addition (input [7:0] matrix_a [0:3][0:1], input [7:0] matrix_b [0:3][0:1], output [7:0] matrix_sum [0:3][0:1]);
assign matrix_sum[0][0] = matrix_a[0][0] + matrix_b[0][0];
assign matrix_sum[0][1] = matrix_a[0][1] + matrix_b[0][1];
assign matrix_sum[1][0] = matrix_a[1][0] + matrix_b[1][0];
assign matrix_sum[1][1] = matrix_a[1][1] + matrix_b[1][1];
assign matrix_sum[2][0] = matrix_a[2][0] + matrix_b[2][0];
assign matrix_sum[2][1] = matrix_a[2][1] + matrix_b[2][1];
assign matrix_sum[3][0] = matrix_a[3][0] + matrix_b[3][0];
assign matrix_sum[3][1] = matrix_a[3][1] + matrix_b[3][1];
endmodule