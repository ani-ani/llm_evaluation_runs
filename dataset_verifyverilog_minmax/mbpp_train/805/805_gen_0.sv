module max_sum_list (
  input [3:0][2:0][7:0] lists, // 4 lists, each with 3 elements (8-bit signed)
  output reg [2:0][7:0] max_list, // The list with highest sum
  output [8:0] max_sum // The actual sum of max_list (9-bit, signed semantics)
);

  // Compute sums of all 4 lists in parallel (combinational)
  wire signed [8:0] sum [0:3];
  genvar i;
  generate
    for (i = 0; i < 4; i = i + 1) begin : sum_calc
      assign sum[i] = $signed({1'b0, lists[i][0]}) +
                      $signed({1'b0, lists[i][1]}) +
                      $signed({1'b0, lists[i][2]});
    end
  endgenerate

  // Find the list with the maximum sum (first occurrence on ties)
  integer j;
  reg [1:0] max_idx;
  always @* begin
    max_idx = 0;
    for (j = 1; j < 4; j = j + 1) begin
      if ($signed(sum[j]) > $signed(sum[max_idx]))
        max_idx = j;
    end
    max_list = lists[max_idx];
  end

  // Output the max sum (9-bit)
  assign max_sum = sum[max_idx];

endmodule
