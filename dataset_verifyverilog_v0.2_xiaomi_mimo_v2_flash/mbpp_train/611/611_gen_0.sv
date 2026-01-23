module max_of_nth (
    input [1:0] column_index,
    input [2:0][2:0][7:0] matrix,
    output logic [7:0] max_value
);

    logic [7:0] col_vals [0:2];
    logic [7:0] layer1_max [0:1];

    // Extract values from the specified column for each row
    always_comb begin
        col_vals[0] = matrix[0][column_index];
        col_vals[1] = matrix[1][column_index];
        col_vals[2] = matrix[2][column_index];
    end

    // Tree of comparators
    // Layer 1: Compare (0 vs 1) and (2 vs dummy)
    assign layer1_max[0] = (col_vals[0] > col_vals[1]) ? col_vals[0] : col_vals[1];
    assign layer1_max[1] = col_vals[2];

    // Layer 2: Final comparison
    assign max_value = (layer1_max[0] > layer1_max[1]) ? layer1_max[0] : layer1_max[1];

endmodule
