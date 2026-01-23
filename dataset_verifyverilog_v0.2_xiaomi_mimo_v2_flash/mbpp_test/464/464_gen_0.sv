module check_values_same (
    input [7:0] target_value,
    input [3:0][7:0] array_values,
    output result
);

    wire [3:0] comp_results;

    // Compare each array element against target value
    assign comp_results[0] = (array_values[0] == target_value);
    assign comp_results[1] = (array_values[1] == target_value);
    assign comp_results[2] = (array_values[2] == target_value);
    assign comp_results[3] = (array_values[3] == target_value);

    // AND all comparison results
    assign result = &comp_results;

endmodule