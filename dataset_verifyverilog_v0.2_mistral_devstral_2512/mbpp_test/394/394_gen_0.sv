module check_distinct (
  input [7:0] data_in [0:7],
  output reg is_distinct
);

  wire [0:27] any_duplicate;
  integer i, j, k;

  // Initialize any_duplicate to 0
  assign any_duplicate = 28'b0;

  // Generate all pairwise comparisons
  always @* begin
    any_duplicate = 28'b0;
    k = 0;
    for (i = 0; i < 8; i = i + 1) begin
      for (j = i + 1; j < 8; j = j + 1) begin
        any_duplicate[k] = (data_in[i] == data_in[j]);
        k = k + 1;
      end
    end
  end

  // Set output based on any duplicate found
  assign is_distinct = !|any_duplicate;

endmodule