module append_arrays (
  input [3:0] tuple_array [1:0], // 2-element tuple
  input [3:0] list_array  [2:0], // 3-element list
  output wire [3:0] result_array [4:0] // 5-element concatenated result
);

  // Assign outputs via generate to avoid order dependence
  genvar i;
  generate
    for (i = 0; i < 2; i++) begin : tuple_part
      assign result_array[i] = tuple_array[i];
    end
    for (i = 0; i < 3; i++) begin : list_part
      assign result_array[i + 2] = list_array[i];
    end
  endgenerate

endmodule