module unique_numbers (
  input reg [3:0] nums [0:7],   // 8-element array of 4-bit numbers
  input reg [2:0] length,        // Valid elements count (3-bit: max 8)
  output reg [3:0] unique_nums [0:7], // Array of unique elements
  output reg [7:0] valid_mask    // Bitmask indicating valid unique elements
);
  // Parallel comparator network and duplicate counting for 8 elements (4-bit values)
  // Compute duplicate matches for each position (excluding self-match), and pack uniques.

  // Pairwise equality (combinational comparators), gated by valid ranges
  wire [55:0] eq; // 8*7 = 56 comparators flattened: e.g., comp[7][0]..comp[0][1]

  // Map comparators: comp[i][j] -> eq[((i*8)+j)] but we skip j==i by starting at 1
  // Unrolled for performance and clarity
  // Row i=0
  assign eq[0]  = (nums[0] == nums[1]) & (0 < length) & (1 < length);
  assign eq[1]  = (nums[0] == nums[2]) & (0 < length) & (2 < length);
  assign eq[2]  = (nums[0] == nums[3]) & (0 < length) & (3 < length);
  assign eq[3]  = (nums[0] == nums[4]) & (0 < length) & (4 < length);
  assign eq[4]  = (nums[0] == nums[5]) & (0 < length) & (5 < length);
  assign eq[5]  = (nums[0] == nums[6]) & (0 < length) & (6 < length);
  assign eq[6]  = (nums[0] == nums[7]) & (0 < length) & (7 < length);
  // Row i=1
  assign eq[7]  = (nums[1] == nums[0]) & (1 < length) & (0 < length);
  assign eq[8]  = (nums[1] == nums[2]) & (1 < length) & (2 < length);
  assign eq[9]  = (nums[1] == nums[3]) & (1 < length) & (3 < length);
  assign eq[10] = (nums[1] == nums[4]) & (1 < length) & (4 < length);
  assign eq[11] = (nums[1] == nums[5]) & (1 < length) & (5 < length);
  assign eq[12] = (nums[1] == nums[6]) & (1 < length) & (6 < length);
  assign eq[13] = (nums[1] == nums[7]) & (1 < length) & (7 < length);
  // Row i=2
  assign eq[14] = (nums[2] == nums[0]) & (2 < length) & (0 < length);
  assign eq[15] = (nums[2] == nums[1]) & (2 < length) & (1 < length);
  assign eq[16] = (nums[2] == nums[3]) & (2 < length) & (3 < length);
  assign eq[17] = (nums[2] == nums[4]) & (2 < length) & (4 < length);
  assign eq[18] = (nums[2] == nums[5]) & (2 < length) & (5 < length);
  assign eq[19] = (nums[2] == nums[6]) & (2 < length) & (6 < length);
  assign eq[20] = (nums[2] == nums[7]) & (2 < length) & (7 < length);
  // Row i=3
  assign eq[21] = (nums[3] == nums[0]) & (3 < length) & (0 < length);
  assign eq[22] = (nums[3] == nums[1]) & (3 < length) & (1 < length);
  assign eq[23] = (nums[3] == nums[2]) & (3 < length) & (2 < length);
  assign eq[24] = (nums[3] == nums[4]) & (3 < length) & (4 < length);
  assign eq[25] = (nums[3] == nums[5]) & (3 < length) & (5 < length);
  assign eq[26] = (nums[3] == nums[6]) & (3 < length) & (6 < length);
  assign eq[27] = (nums[3] == nums[7]) & (3 < length) & (7 < length);
  // Row i=4
  assign eq[28] = (nums[4] == nums[0]) & (4 < length) & (0 < length);
  assign eq[29] = (nums[4] == nums[1]) & (4 < length) & (1 < length);
  assign eq[30] = (nums[4] == nums[2]) & (4 < length) & (2 < length);
  assign eq[31] = (nums[4] == nums[3]) & (4 < length) & (3 < length);
  assign eq[32] = (nums[4] == nums[5]) & (4 < length) & (5 < length);
  assign eq[33] = (nums[4] == nums[6]) & (4 < length) & (6 < length);
  assign eq[34] = (nums[4] == nums[7]) & (4 < length) & (7 < length);
  // Row i=5
  assign eq[35] = (nums[5] == nums[0]) & (5 < length) & (0 < length);
  assign eq[36] = (nums[5] == nums[1]) & (5 < length) & (1 < length);
  assign eq[37] = (nums[5] == nums[2]) & (5 < length) & (2 < length);
  assign eq[38] = (nums[5] == nums[3]) & (5 < length) & (3 < length);
  assign eq[39] = (nums[5] == nums[4]) & (5 < length) & (4 < length);
  assign eq[40] = (nums[5] == nums[6]) & (5 < length) & (6 < length);
  assign eq[41] = (nums[5] == nums[7]) & (5 < length) & (7 < length);
  // Row i=6
  assign eq[42] = (nums[6] == nums[0]) & (6 < length) & (0 < length);
  assign eq[43] = (nums[6] == nums[1]) & (6 < length) & (1 < length);
  assign eq[44] = (nums[6] == nums[2]) & (6 < length) & (2 < length);
  assign eq[45] = (nums[6] == nums[3]) & (6 < length) & (3 < length);
  assign eq[46] = (nums[6] == nums[4]) & (6 < length) & (4 < length);
  assign eq[47] = (nums[6] == nums[5]) & (6 < length) & (5 < length);
  assign eq[48] = (nums[6] == nums[7]) & (6 < length) & (7 < length);
  // Row i=7
  assign eq[49] = (nums[7] == nums[0]) & (7 < length) & (0 < length);
  assign eq[50] = (nums[7] == nums[1]) & (7 < length) & (1 < length);
  assign eq[51] = (nums[7] == nums[2]) & (7 < length) & (2 < length);
  assign eq[52] = (nums[7] == nums[3]) & (7 < length) & (3 < length);
  assign eq[53] = (nums[7] == nums[4]) & (7 < length) & (4 < length);
  assign eq[54] = (nums[7] == nums[5]) & (7 < length) & (5 < length);
  assign eq[55] = (nums[7] == nums[6]) & (7 < length) & (6 < length);

  // Duplicate counts (number of other equal elements in the first 'length' positions)
  wire [2:0] dup_cnt [0:7];
  assign dup_cnt[0] = (eq[0] + eq[1] + eq[2] + eq[3] + eq[4] + eq[5] + eq[6]);
  assign dup_cnt[1] = (eq[7] + eq[8] + eq[9] + eq[10] + eq[11] + eq[12] + eq[13]);
  assign dup_cnt[2] = (eq[14] + eq[15] + eq[16] + eq[17] + eq[18] + eq[19] + eq[20]);
  assign dup_cnt[3] = (eq[21] + eq[22] + eq[23] + eq[24] + eq[25] + eq[26] + eq[27]);
  assign dup_cnt[4] = (eq[28] + eq[29] + eq[30] + eq[31] + eq[32] + eq[33] + eq[34]);
  assign dup_cnt[5] = (eq[35] + eq[36] + eq[37] + eq[38] + eq[39] + eq[40] + eq[41]);
  assign dup_cnt[6] = (eq[42] + eq[43] + eq[44] + eq[45] + eq[46] + eq[47] + eq[48]);
  assign dup_cnt[7] = (eq[49] + eq[50] + eq[51] + eq[52] + eq[53] + eq[54] + eq[55]);

  // One-hot mask of unique elements (dup count 0 and within range)
  wire [7:0] uniq_mask;
  assign uniq_mask[0] = (0 < length) & (dup_cnt[0] == 3'd0);
  assign uniq_mask[1] = (1 < length) & (dup_cnt[1] == 3'd0);
  assign uniq_mask[2] = (2 < length) & (dup_cnt[2] == 3'd0);
  assign uniq_mask[3] = (3 < length) & (dup_cnt[3] == 3'd0);
  assign uniq_mask[4] = (4 < length) & (dup_cnt[4] == 3'd0);
  assign uniq_mask[5] = (5 < length) & (dup_cnt[5] == 3'd0);
  assign uniq_mask[6] = (6 < length) & (dup_cnt[6] == 3'd0);
  assign uniq_mask[7] = (7 < length) & (dup_cnt[7] == 3'd0);

  // Generate valid_mask (bitmask) and pack unique values
  always @* begin
    valid_mask = 8'h0;
    unique_nums = '{default: 4'h0};

    // Pack unique values into the output array; order is not required to be preserved
    begin : pack_uniques
      int out_pos;
      for (int i = 0; i < 8; i++) begin
        if (uniq_mask[i]) begin
          out_pos = $unsigned($countones(uniq_mask[0+:i])); // count set bits up to and including i
          if (out_pos < 8) begin
            unique_nums[out_pos] = nums[i];
            valid_mask[out_pos] = 1'b1;
          end
        end
      end
    end
  end
endmodule