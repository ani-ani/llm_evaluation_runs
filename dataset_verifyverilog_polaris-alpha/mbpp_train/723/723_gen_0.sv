module same_value_counter(
  input  signed [5:0] list1 [0:7],
  input  signed [5:0] list2 [0:7],
  output       [3:0] count
);

  wire [3:0] match_count [0:8];

  // Base count
  assign match_count[0] = 4'd0;

  // Generate match counts per index
  assign match_count[1] = match_count[0] + (list1[0] == list2[0]);
  assign match_count[2] = match_count[1] + (list1[1] == list2[1]);
  assign match_count[3] = match_count[2] + (list1[2] == list2[2]);
  assign match_count[4] = match_count[3] + (list1[3] == list2[3]);
  assign match_count[5] = match_count[4] + (list1[4] == list2[4]);
  assign match_count[6] = match_count[5] + (list1[5] == list2[5]);
  assign match_count[7] = match_count[6] + (list1[6] == list2[6]);
  assign match_count[8] = match_count[7] + (list1[7] == list2[7]);

  // Final count
  assign count = match_count[8];

endmodule