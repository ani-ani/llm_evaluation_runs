module max_sum_list(
  input [3:0][2:0][7:0] lists,
  output logic [2:0][7:0] max_list,
  output logic [8:0] max_sum
);

  logic signed [8:0] sums [3:0];
  logic [1:0] max_index;

  always_comb begin
    // Compute sums
    for (int i = 0; i < 4; i++) begin
      sums[i] = $signed(lists[i][0]) + $signed(lists[i][1]) + $signed(lists[i][2]);
    end

    // Find max index
    max_index = 0;
    for (int i = 1; i < 4; i++) begin
      if (sums[i] > sums[max_index]) begin
        max_index = i;
      end
    end

    // Assign outputs
    max_list = lists[max_index];
    max_sum = sums[max_index];
  end

endmodule