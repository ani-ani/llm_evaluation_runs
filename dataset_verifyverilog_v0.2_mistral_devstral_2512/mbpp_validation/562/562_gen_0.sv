module find_max_length (
  input [7:0] valid_mask,
  input [7:0][7:0] lengths,
  output [7:0] max_length
);

  wire [7:0] stage1_max [0:3];
  wire [7:0] stage2_max [0:1];
  wire [7:0] stage3_max;

  // Stage 1: Compare pairs (0 vs 1, 2 vs 3, 4 vs 5, 6 vs 7)
  assign stage1_max[0] = (valid_mask[0] && valid_mask[1]) ? (lengths[0] > lengths[1] ? lengths[0] : lengths[1]) :
                         (valid_mask[0] ? lengths[0] : (valid_mask[1] ? lengths[1] : 0));
  assign stage1_max[1] = (valid_mask[2] && valid_mask[3]) ? (lengths[2] > lengths[3] ? lengths[2] : lengths[3]) :
                         (valid_mask[2] ? lengths[2] : (valid_mask[3] ? lengths[3] : 0));
  assign stage1_max[2] = (valid_mask[4] && valid_mask[5]) ? (lengths[4] > lengths[5] ? lengths[4] : lengths[5]) :
                         (valid_mask[4] ? lengths[4] : (valid_mask[5] ? lengths[5] : 0));
  assign stage1_max[3] = (valid_mask[6] && valid_mask[7]) ? (lengths[6] > lengths[7] ? lengths[6] : lengths[7]) :
                         (valid_mask[6] ? lengths[6] : (valid_mask[7] ? lengths[7] : 0));

  // Stage 2: Compare results of Stage 1 (0-1 vs 2-3, 4-5 vs 6-7)
  assign stage2_max[0] = (stage1_max[0] > stage1_max[1]) ? stage1_max[0] : stage1_max[1];
  assign stage2_max[1] = (stage1_max[2] > stage1_max[3]) ? stage1_max[2] : stage1_max[3];

  // Stage 3: Final comparison of Stage 2 results
  assign stage3_max = (stage2_max[0] > stage2_max[1]) ? stage2_max[0] : stage2_max[1];

  // Output the final result
  assign max_length = stage3_max;

endmodule