module matrix_row_average (
    input [3:0][3:0][15:0] matrix_data,
    output [3:0][15:0] averages
);

    // Declare wires for intermediate sums (18 bits to accommodate sum of 4 Q16.16 values)
    wire [17:0] row_sums [3:0];

    // Generate block to compute row sums
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : row_sum_gen
            assign row_sums[i] = matrix_data[i][0] + matrix_data[i][1] + matrix_data[i][2] + matrix_data[i][3];
        end
    endgenerate

    // Generate block to compute averages (shift right by 2)
    generate
        for (i = 0; i < 4; i = i + 1) begin : row_avg_gen
            assign averages[i] = row_sums[i][17:2];
        end
    endgenerate

endmodule