module matrix_row_average (
    input [3:0][3:0][15:0] matrix_data,
    output logic [3:0][15:0] averages
);

    // Intermediate sum storage: 4 rows, 34 bits to accommodate sum of 4 Q16.16 values
    logic [3:0][33:0] row_sums;

    // Generate blocks for parallel computation of row sums
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : row_processing
            // Sum all 4 values in the row with zero-extended operands
            // Each value is 16 bits, sum requires 18 bits minimum, we use 34 bits for safety
            assign row_sums[i] = {18'b0, matrix_data[i][0]} + 
                                 {18'b0, matrix_data[i][1]} + 
                                 {18'b0, matrix_data[i][2]} + 
                                 {18'b0, matrix_data[i][3]};
            
            // Divide by 4 using shift right by 2
            // Take bits [17:2] from the sum for the Q16.16 result
            // row_sums[i][17:2] corresponds to the 16-bit Q16.16 result
            assign averages[i] = row_sums[i][17:2];
        end
    endgenerate

endmodule
