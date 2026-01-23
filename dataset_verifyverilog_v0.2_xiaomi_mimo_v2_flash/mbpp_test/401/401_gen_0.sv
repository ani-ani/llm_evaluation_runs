module matrix_addition(
    input [7:0] matrix_a [0:3][0:1],
    input [7:0] matrix_b [0:3][0:1],
    output logic [7:0] matrix_sum [0:3][0:1]
);
    // Combinational element-wise addition for all 8 elements
    always_comb begin
        integer i, j;
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 2; j = j + 1) begin
                matrix_sum[i][j] = matrix_a[i][j] + matrix_b[i][j];
            end
        end
    end
endmodule