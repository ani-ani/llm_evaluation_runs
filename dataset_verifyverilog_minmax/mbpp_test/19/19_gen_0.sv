module duplicate_checker (
  input [7:0] array [0:7],
  output logic has_duplicate
);

  // Flattened view of the array for indexing convenience
  logic [7:0] flat [0:7];
  for (genvar i = 0; i < 8; i++) begin : flatten
    assign flat[i] = array[i];
  end

  // Parallel comparison: each element compared with all subsequent elements
  logic any_dup;
  always_comb begin
    any_dup = 1'b0;
    for (int i = 0; i < 8; i++) begin
      for (int j = i + 1; j < 8; j++) begin
        if (flat[i] == flat[j]) any_dup = 1'b1;
      end
    end
    has_duplicate = any_dup;
  end

endmodule