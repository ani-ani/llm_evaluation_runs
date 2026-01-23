module max_sum_list (
  input [2:0][3:0] list_0,
  input [2:0][3:0] list_1,
  input [2:0][3:0] list_2,
  input [2:0][3:0] list_3,
  output [2:0][3:0] max_list
);

  // Calculate sums for each list (4-bit signed elements)
  wire [5:0] sum_0 = $signed(list_0[0]) + $signed(list_0[1]) + $signed(list_0[2]);
  wire [5:0] sum_1 = $signed(list_1[0]) + $signed(list_1[1]) + $signed(list_1[2]);
  wire [5:0] sum_2 = $signed(list_2[0]) + $signed(list_2[1]) + $signed(list_2[2]);
  wire [5:0] sum_3 = $signed(list_3[0]) + $signed(list_3[1]) + $signed(list_3[2]);

  // Compare sums to find the maximum
  wire [1:0] max_index;
  assign max_index = (sum_0 > sum_1) ? ((sum_0 > sum_2) ? ((sum_0 > sum_3) ? 2'd0 : 2'd3) : ((sum_2 > sum_3) ? 2'd2 : 2'd3)) : ((sum_1 > sum_2) ? ((sum_1 > sum_3) ? 2'd1 : 2'd3) : ((sum_2 > sum_3) ? 2'd2 : 2'd3));

  // Select the list with maximum sum
  assign max_list = (max_index == 2'd0) ? list_0 :
                    (max_index == 2'd1) ? list_1 :
                    (max_index == 2'd2) ? list_2 :
                    list_3;

endmodule