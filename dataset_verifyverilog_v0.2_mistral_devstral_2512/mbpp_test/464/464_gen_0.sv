module check_values_same (
  input [7:0] target_value,
  input [3:0][7:0] array_values,
  output result
);

  wire [3:0] compare_results;

  // Parallel comparators
  assign compare_results[0] = (array_values[0] == target_value);
  assign compare_results[1] = (array_values[1] == target_value);
  assign compare_results[2] = (array_values[2] == target_value);
  assign compare_results[3] = (array_values[3] == target_value);

  // 4-input AND gate
  assign result = compare_results[0] & compare_results[1] & compare_results[2] & compare_results[3];

endmodule