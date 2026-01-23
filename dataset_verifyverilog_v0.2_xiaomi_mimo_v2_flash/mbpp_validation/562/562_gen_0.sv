module find_max_length (
    input [7:0] valid_mask,
    input [7:0][7:0] lengths,
    output reg [7:0] max_length
);

    // Intermediate comparison results for Stage 1
    wire [7:0] stage1_max [0:3];
    wire [0:3] stage1_valid;

    // Stage 1: Compare pairs (0 vs 1, 2 vs 3, 4 vs 5, 6 vs 7)
    // Pair 0-1
    assign stage1_valid[0] = valid_mask[0] | valid_mask[1];
    assign stage1_max[0] = (!valid_mask[1] || (valid_mask[0] && lengths[0] >= lengths[1])) ? lengths[0] : lengths[1];

    // Pair 2-3
    assign stage1_valid[1] = valid_mask[2] | valid_mask[3];
    assign stage1_max[1] = (!valid_mask[3] || (valid_mask[2] && lengths[2] >= lengths[3])) ? lengths[2] : lengths[3];

    // Pair 4-5
    assign stage1_valid[2] = valid_mask[4] | valid_mask[5];
    assign stage1_max[2] = (!valid_mask[5] || (valid_mask[4] && lengths[4] >= lengths[5])) ? lengths[4] : lengths[5];

    // Pair 6-7
    assign stage1_valid[3] = valid_mask[6] | valid_mask[7];
    assign stage1_max[3] = (!valid_mask[7] || (valid_mask[6] && lengths[6] >= lengths[7])) ? lengths[6] : lengths[7];

    // Intermediate comparison results for Stage 2
    wire [7:0] stage2_max [0:1];
    wire [0:1] stage2_valid;

    // Stage 2: Compare results of Stage 1 (0-1 vs 2-3, 4-5 vs 6-7)
    // Group 0: Pair 0-1 vs Pair 2-3
    assign stage2_valid[0] = stage1_valid[0] | stage1_valid[1];
    assign stage2_max[0] = (!stage1_valid[1] || (stage1_valid[0] && stage1_max[0] >= stage1_max[1])) ? stage1_max[0] : stage1_max[1];

    // Group 1: Pair 4-5 vs Pair 6-7
    assign stage2_valid[1] = stage1_valid[2] | stage1_valid[3];
    assign stage2_max[1] = (!stage1_valid[3] || (stage1_valid[2] && stage1_max[2] >= stage1_max[3])) ? stage1_max[2] : stage1_max[3];

    // Stage 3: Final comparison of Stage 2 results
    // If both valid, compare. If only one valid, take that one. If none valid, 0.
    always @(*) begin
        if (stage2_valid[0] && stage2_valid[1]) begin
            max_length = (stage2_max[0] >= stage2_max[1]) ? stage2_max[0] : stage2_max[1];
        end else if (stage2_valid[0]) begin
            max_length = stage2_max[0];
        end else if (stage2_valid[1]) begin
            max_length = stage2_max[1];
        end else begin
            max_length = 8'b0;
        end
    end

endmodule