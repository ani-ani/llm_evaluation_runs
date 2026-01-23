module find_max (
  input [7:0] data_in [0:7],
  output [7:0] max_value
);

  // First stage: compare pairs (4 comparisons)
  wire [7:0] max_stage1 [0:3];
  assign max_stage1[0] = (data_in[0] > data_in[1]) ? data_in[0] : data_in[1];
  assign max_stage1[1] = (data_in[2] > data_in[3]) ? data_in[2] : data_in[3];
  assign max_stage1[2] = (data_in[4] > data_in[5]) ? data_in[4] : data_in[5];
  assign max_stage1[3] = (data_in[6] > data_in[7]) ? data_in[6] : data_in[7];

  // Second stage: compare winners (2 comparisons)
  wire [7:0] max_stage2 [0:1];
  assign max_stage2[0] = (max_stage1[0] > max_stage1[1]) ? max_stage1[0] : max_stage1[1];
  assign max_stage2[1] = (max_stage1[2] > max_stage1[3]) ? max_stage1[2] : max_stage1[3];

  // Final stage: compare last two winners
  assign max_value = (max_stage2[0] > max_stage2[1]) ? max_stage2[0] : max_stage2[1];

endmodule