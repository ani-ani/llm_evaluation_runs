module sorted_common_elements (
  input clk,
  input rst_n,
  input start,
  input [15:0] l1 [0:7],
  input [15:0] l2 [0:7],
  input [3:0] len1,
  input [3:0] len2,
  output reg [15:0] result [0:7],
  output reg [3:0] result_len,
  output reg done
);

  // Stage 0: Find common elements (parallel compare) and keep original order + deduplicate on-the-fly
  function [15:0] compare_pair;
    input [15:0] a;
    input [15:0] b;
    input [3:0] a_len;
    input [3:0] b_len;
    begin
      compare_pair = (a == b) && (a_len > 0) && (b_len > 0) ? a : '0;
    end
  endfunction

  function [7:0] dedup_mask;
    input [15:0] val;
    input [15:0] prev [0:7];
    input [7:0] prev_valid;
    input [3:0] k;
    begin
      // Keep the first occurrence (smallest k) to maintain original order during deduplication.
      dedup_mask = '0;
      if (k < 8) begin
        // If any previous valid value equals val, mark this position as duplicate.
        for (int i = 0; i < 8; i++) begin
          if (prev_valid[i] && (prev[i] == val)) begin
            dedup_mask[k] = 1'b1;
          end
        end
      end
    end
  endfunction

  // Stage 0 signals
  logic [15:0] common_stage0 [0:7];
  logic [7:0] dup_flag_stage0; // 1 = duplicate (drop)
  logic [3:0] result_len_stage1;
  logic [15:0] result_stage1 [0:7];
  logic [15:0] result_stage2 [0:7];
  logic [3:0] result_len_stage2;

  // Parallel comparison to find common elements in the original order of l1
  always_comb begin
    for (int i = 0; i < 8; i++) begin
      common_stage0[i] = compare_pair(l1[i], l2[0], len1, len2);
      for (int j = 1; j < 8; j++) begin
        if (compare_pair(l1[i], l2[j], len1, len2) != '0) begin
          common_stage0[i] = l1[i]; // If any match found in l2, keep the l1[i] (preserve order)
        end
      end
    end
  end

  // Deduplicate common elements in the order they appear (from l1) using a first-occurrence policy
  always_comb begin
    dup_flag_stage0 = '0;
    for (int k = 0; k < 8; k++) begin
      if (k < len1) begin
        dup_flag_stage0[k] = dedup_mask(common_stage0[k], common_stage0, (k > 0) ? ~dup_flag_stage0 & ((1 << k) - 1) : '0, k);
      end else begin
        dup_flag_stage0[k] = 1'b0;
      end
    end
  end

  // Bitonic sorting network (8 inputs, ascending, stable by index)
  function [15:0] bitonic8;
    input [15:0] in [0:7];
    input [7:0] valid;
    input [3:0] n;
    var [15:0] data [0:7];
    var [7:0] vld;
    var [15:0] tmp [0:7];
    var [7:0] t_vld;
    begin
      data = in;
      vld = valid;

      // Stage 0
      for (int i = 0; i < 8; i += 2) begin
        if (vld[i] && vld[i+1] && data[i] > data[i+1]) begin
          tmp[i] = data[i+1]; tmp[i+1] = data[i];
          t_vld[i] = vld[i]; t_vld[i+1] = vld[i+1];
        end else begin
          tmp[i] = data[i]; tmp[i+1] = data[i+1];
          t_vld[i] = vld[i]; t_vld[i+1] = vld[i+1];
        end
      end
      data = tmp; vld = t_vld;

      // Stage 1
      for (int i = 1; i < 8; i += 2) begin
        if (vld[i] && vld[i+1] && data[i] > data[i+1]) begin
          tmp[i] = data[i+1]; tmp[i+1] = data[i];
          t_vld[i] = vld[i]; t_vld[i+1] = vld[i+1];
        end else begin
          tmp[i] = data[i]; tmp[i+1] = data[i+1];
          t_vld[i] = vld[i]; t_vld[i+1] = vld[i+1];
        end
      end
      data = tmp; vld = t_vld;

      // Stage 2 (4)
      for (int i = 0; i < 8; i += 4) begin
        if (vld[i] && vld[i+2] && data[i] > data[i+2]) begin
          tmp[i] = data[i+2]; tmp[i+2] = data[i]; t_vld[i] = vld[i]; t_vld[i+2] = vld[i+2];
        end else begin
          tmp[i] = data[i]; tmp[i+2] = data[i+2]; t_vld[i] = vld[i]; t_vld[i+2] = vld[i+2];
        end
        if (vld[i+1] && vld[i+3] && data[i+1] > data[i+3]) begin
          tmp[i+1] = data[i+3]; tmp[i+3] = data[i+1]; t_vld[i+1] = vld[i+1]; t_vld[i+3] = vld[i+3];
        end else begin
          tmp[i+1] = data[i+1]; tmp[i+3] = data[i+3]; t_vld[i+1] = vld[i+1]; t_vld[i+3] = vld[i+3];
        end
      end
      data = tmp; vld = t_vld;

      // Stage 3 (2)
      for (int i = 0; i < 8; i += 2) begin
        if (vld[i] && vld[i+1] && data[i] > data[i+1]) begin
          tmp[i] = data[i+1]; tmp[i+1] = data[i];
          t_vld[i] = vld[i]; t_vld[i+1] = vld[i+1];
        end else begin
          tmp[i] = data[i]; tmp[i+1] = data[i+1];
          t_vld[i] = vld[i]; t_vld[i+1] = vld[i+1];
        end
      end
      data = tmp; vld = t_vld;

      bitonic8 = data;
    end
  endfunction

  // Stage 1: pack uniques + count, then sort
  always_comb begin
    // Unpacked: keep value only if not a duplicate
    for (int i = 0; i < 8; i++) begin
      if (dup_flag_stage0[i]) begin
        result_stage1[i] = '0;
      end else begin
        result_stage1[i] = common_stage0[i];
      end
    end
    result_len_stage1 = 0;
    for (int i = 0; i < 8; i++) begin
      if (!dup_flag_stage0[i] && (common_stage0[i] != '0)) begin
        result_len_stage1++;
      end
    end

    // Sorting network (stable with index)
    result_stage2 = bitonic8(result_stage1, ~dup_flag_stage0 & ((1 << result_len_stage1) - 1), result_len_stage1);
    result_len_stage2 = result_len_stage1;
  end

  // Output registers: capture one cycle after start
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= '{default: '0};
      result_len <= 4'd0;
      done <= 1'b0;
    end else begin
      if (start) begin
        result <= result_stage2;
        result_len <= result_len_stage2;
        done <= 1'b1;
      end else begin
        done <= 1'b0;
      end
    end
  end

endmodule
