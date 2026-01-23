module find_min (
  input [7:0] data_in [0:7],
  output [7:0] min_value
);

  wire [7:0] min_stage1 [0:3];
  wire [7:0] min_stage2 [0:1];

  // Stage 1: Compare pairs
  assign min_stage1[0] = (data_in[0] < data_in[1]) ? data_in[0] : data_in[1];
  assign min_stage1[1] = (data_in[2] < data_in[3]) ? data_in[2] : data_in[3];
  assign min_stage1[2] = (data_in[4] < data_in[5]) ? data_in[4] : data_in[5];
  assign min_stage1[3] = (data_in[6] < data_in[7]) ? data_in[6] : data_in[7];

  // Stage 2: Compare results from stage 1
  assign min_stage2[0] = (min_stage1[0] < min_stage1[1]) ? min_stage1[0] : min_stage1[1];
  assign min_stage2[1] = (min_stage1[2] < min_stage1[3]) ? min_stage1[2] : min_stage1[3];

  // Final stage: Compare last two results
  assign min_value = (min_stage2[0] < min_stage2[1]) ? min_stage2[0] : min_stage2[1];

endmodule