module matrix_row_average (
    input [3:0][3:0][15:0] matrix_data,
    output [3:0][15:0] averages
);
assign averages[0] = (matrix_data[0][0] + matrix_data[0][1] + matrix_data[0][2] + matrix_data[0][3]) >> 2;
assign averages[1] = (matrix_data[1][0] + matrix_data[1][1] + matrix_data[1][2] + matrix_data[1][3]) >> 2;
assign averages[2] = (matrix_data[2][0] + matrix_data[2][1] + matrix_data[2][2] + matrix_data[2][3]) >> 2;
assign averages[3] = (matrix_data[3][0] + matrix_data[3][1] + matrix_data[3][2] + matrix_data[3][3]) >> 2);
endmodule