module tv_coverage(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start computation
  input [4:0] city_length, // Max 31 units (5-bit)
  input [0:7] has_transmitter, // 8 buildings mask (1-bit per building)
  input [4:0] building_pos[0:7], // Positions (5-bit each)
  input [4:0] building_height[0:7], // Heights (5-bit each)
  output reg [15:0] coverage_length, // Q12.4 format
  output reg done // High when computation complete
);

  // Internal signals and registers
  integer i;
  reg [4:0] city_len_r;
  reg [7:0] tx_mask_r;
  reg [4:0] pos_r [0:7];
  reg [4:0] h_r [0:7];

  // Pipelined state for forward scan (nearest blocking building on the right)
  // Stage s handles building index s
  reg [15:0] s0_max_slope, s1_max_slope, s2_max_slope, s3_max_slope;
  reg [15:0] s4_max_slope, s5_max_slope, s6_max_slope, s7_max_slope;
  reg [4:0] s0_min_block, s1_min_block, s2_min_block, s3_min_block;
  reg [4:0] s4_min_block, s5_min_block, s6_min_block, s7_min_block;
  reg s0_has_tx, s1_has_tx, s2_has_tx, s3_has_tx;
  reg s4_has_tx, s5_has_tx, s6_has_tx, s7_has_tx;

  // Pipelined state for reverse scan (nearest blocking building on the left)
  reg [15:0] s0_max_rev_slope, s1_max_rev_slope, s2_max_rev_slope, s3_max_rev_slope;
  reg [15:0] s4_max_rev_slope, s5_max_rev_slope, s6_max_rev_slope, s7_max_rev_slope;
  reg [4:0] s0_max_right, s1_max_right, s2_max_right, s3_max_right;
  reg [4:0] s4_max_right, s5_max_right, s6_max_right, s7_max_right;
  reg s0_has_tx_r, s1_has_tx_r, s2_has_tx_r, s3_has_tx_r;
  reg s4_has_tx_r, s5_has_tx_r, s6_has_tx_r, s7_has_tx_r;

  // Coverage marking array (1-bit per unit along city_length)
  reg cov_units [0:31];

  // Summation of covered units (Q0.0) then scaled to Q12.4
  reg [5:0] covered_units;
  reg [15:0] sum_scaled;

  // Reset coverage bits
  task reset_coverage;
    for (i = 0; i < 32; i = i + 1) cov_units[i] = 1'b0;
  endtask

  // Mark coverage from L (inclusive) to R (exclusive), clipped to [0, city_len_r]
  task mark_coverage;
    input [4:0] L;
    input [4:0] R;
    reg [4:0] l, r;
    begin
      l = (L < R) ? L : R;
      r = (R > L) ? R : L;
      if (city_len_r == 5'd0) begin
        // nothing to do
      end else begin
        if (l > city_len_r) l = city_len_r;
        if (r > city_len_r) r = city_len_r;
        for (i = 0; i < 32; i = i + 1) begin
          if (i >= l && i < r) cov_units[i] = 1'b1;
        end
      end
    end
  endtask

  // Compute slope in Q12.4: slope = ((h_tx - h_b) << 4) / (pos_tx - pos_b)
  // Returns 16'h7FFF if dx <= 0 (to represent a large positive slope)
  function [15:0] slope_q12_4;
    input [4:0] h_tx, h_b;
    input [4:0] pos_tx, pos_b;
    reg signed [5:0] dx;
    reg signed [15:0] dy_s;
    reg [15:0] dy_u;
    reg [15:0] slope;
    begin
      dx = $signed(pos_tx) - $signed(pos_b);
      if (dx <= 0) begin
        slope = 16'h7FFF; // large positive slope (non-blocking for comparisons)
      end else begin
        dy_s = $signed({1'b0, h_tx}) - $signed({1'b0, h_b}); // signed diff
        if (dy_s < 0) dy_u = 16'h0000; else dy_u = {1'b0, dy_s[14:0]};
        // dy << 4 (Q8.4 -> Q12.4), then / dx (integer)
        slope = (dy_u << 4) / dx;
      end
      slope_q12_4 = slope;
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      coverage_length <= 16'h0000;
      done <= 1'b0;
      city_len_r <= 5'd0;
      tx_mask_r <= 8'd0;
      for (i = 0; i < 8; i = i + 1) begin
        pos_r[i] <= 5'd0;
        h_r[i] <= 5'd0;
      end
      s0_max_slope <= 16'h0000; s1_max_slope <= 16'h0000; s2_max_slope <= 16'h0000; s3_max_slope <= 16'h0000;
      s4_max_slope <= 16'h0000; s5_max_slope <= 16'h0000; s6_max_slope <= 16'h0000; s7_max_slope <= 16'h0000;
      s0_min_block <= 5'd31; s1_min_block <= 5'd31; s2_min_block <= 5'd31; s3_min_block <= 5'd31;
      s4_min_block <= 5'd31; s5_min_block <= 5'd31; s6_min_block <= 5'd31; s7_min_block <= 5'd31;
      s0_has_tx <= 1'b0; s1_has_tx <= 1'b0; s2_has_tx <= 1'b0; s3_has_tx <= 1'b0;
      s4_has_tx <= 1'b0; s5_has_tx <= 1'b0; s6_has_tx <= 1'b0; s7_has_tx <= 1'b0;
      s0_max_rev_slope <= 16'h0000; s1_max_rev_slope <= 16'h0000; s2_max_rev_slope <= 16'h0000; s3_max_rev_slope <= 16'h0000;
      s4_max_rev_slope <= 16'h0000; s5_max_rev_slope <= 16'h0000; s6_max_rev_slope <= 16'h0000; s7_max_rev_slope <= 16'h0000;
      s0_max_right <= 5'd0; s1_max_right <= 5'd0; s2_max_right <= 5'd0; s3_max_right <= 5'd0;
      s4_max_right <= 5'd0; s5_max_right <= 5'd0; s6_max_right <= 5'd0; s7_max_right <= 5'd0;
      s0_has_tx_r <= 1'b0; s1_has_tx_r <= 1'b0; s2_has_tx_r <= 1'b0; s3_has_tx_r <= 1'b0;
      s4_has_tx_r <= 1'b0; s5_has_tx_r <= 1'b0; s6_has_tx_r <= 1'b0; s7_has_tx_r <= 1'b0;
      covered_units <= 6'd0;
      sum_scaled <= 16'h0000;
      reset_coverage;
    end else begin
      // Latch inputs on start (sampled once per run)
      if (start) begin
        city_len_r <= city_length;
        tx_mask_r <= has_transmitter;
        for (i = 0; i < 8; i = i + 1) begin
          pos_r[i] <= building_pos[i];
          h_r[i] <= building_height[i];
        end
        reset_coverage;
        done <= 1'b0;
        // Reset pipeline
        s0_max_slope <= 16'h0000; s1_max_slope <= 16'h0000; s2_max_slope <= 16'h0000; s3_max_slope <= 16'h0000;
        s4_max_slope <= 16'h0000; s5_max_slope <= 16'h0000; s6_max_slope <= 16'h0000; s7_max_slope <= 16'h0000;
        s0_min_block <= 5'd31; s1_min_block <= 5'd31; s2_min_block <= 5'd31; s3_min_block <= 5'd31;
        s4_min_block <= 5'd31; s5_min_block <= 5'd31; s6_min_block <= 5'd31; s7_min_block <= 5'd31;
        s0_has_tx <= 1'b0; s1_has_tx <= 1'b0; s2_has_tx <= 1'b0; s3_has_tx <= 1'b0;
        s4_has_tx <= 1'b0; s5_has_tx <= 1'b0; s6_has_tx <= 1'b0; s7_has_tx <= 1'b0;
        s0_max_rev_slope <= 16'h0000; s1_max_rev_slope <= 16'h0000; s2_max_rev_slope <= 16'h0000; s3_max_rev_slope <= 16'h0000;
        s4_max_rev_slope <= 16'h0000; s5_max_rev_slope <= 16'h0000; s6_max_rev_slope <= 16'h0000; s7_max_rev_slope <= 16'h0000;
        s0_max_right <= 5'd0; s1_max_right <= 5'd0; s2_max_right <= 5'd0; s3_max_right <= 5'd0;
        s4_max_right <= 5'd0; s5_max_right <= 5'd0; s6_max_right <= 5'd0; s7_max_right <= 5'd0;
        s0_has_tx_r <= 1'b0; s1_has_tx_r <= 1'b0; s2_has_tx_r <= 1'b0; s3_has_tx_r <= 1'b0;
        s4_has_tx_r <= 1'b0; s5_has_tx_r <= 1'b0; s6_has_tx_r <= 1'b0; s7_has_tx_r <= 1'b0;
        covered_units <= 6'd0;
        sum_scaled <= 16'h0000;
      end else begin
        // Forward scan pipeline: each stage s computes for building s
        // Stage 0 (building 0)
        s0_has_tx <= tx_mask_r[0];
        begin
          reg [15:0] slope;
          slope = slope_q12_4(h_r[0], h_r[0], pos_r[0], pos_r[0]);
          s0_max_slope <= slope;
          s0_min_block <= 5'd31; // no building to the left
        end
        // Stage 1 (building 1)
        s1_has_tx <= tx_mask_r[1];
        begin
          reg [15:0] slope, cmp_slope;
          reg [4:0] block_pos;
          slope = slope_q12_4(h_r[1], h_r[1], pos_r[1], pos_r[1]);
          cmp_slope = s0_max_slope;
          // If building 0 blocks building 1, block_pos = pos_r[0]; else 31
          if (h_r[0] >= (h_r[1] + ((pos_r[1] > pos_r[0]) ? ((pos_r[1] - pos_r[0]) * s0_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[0];
          else
            block_pos = 5'd31;
          s1_max_slope <= (slope > cmp_slope) ? slope : cmp_slope;
          s1_min_block <= block_pos;
        end
        // Stage 2 (building 2)
        s2_has_tx <= tx_mask_r[2];
        begin
          reg [15:0] slope, cmp_slope;
          reg [4:0] block_pos;
          slope = slope_q12_4(h_r[2], h_r[2], pos_r[2], pos_r[2]);
          cmp_slope = s1_max_slope;
          // Check blocking by nearest among buildings 0..1
          // Compare against building 0 first
          if (h_r[0] >= (h_r[2] + ((pos_r[2] > pos_r[0]) ? ((pos_r[2] - pos_r[0]) * s1_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[0];
          else if (h_r[1] >= (h_r[2] + ((pos_r[2] > pos_r[1]) ? ((pos_r[2] - pos_r[1]) * s1_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[1];
          else
            block_pos = 5'd31;
          s2_max_slope <= (slope > cmp_slope) ? slope : cmp_slope;
          s2_min_block <= block_pos;
        end
        // Stage 3 (building 3)
        s3_has_tx <= tx_mask_r[3];
        begin
          reg [15:0] slope, cmp_slope;
          reg [4:0] block_pos;
          slope = slope_q12_4(h_r[3], h_r[3], pos_r[3], pos_r[3]);
          cmp_slope = s2_max_slope;
          // Check buildings 0..2
          if (h_r[0] >= (h_r[3] + ((pos_r[3] > pos_r[0]) ? ((pos_r[3] - pos_r[0]) * s2_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[0];
          else if (h_r[1] >= (h_r[3] + ((pos_r[3] > pos_r[1]) ? ((pos_r[3] - pos_r[1]) * s2_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[1];
          else if (h_r[2] >= (h_r[3] + ((pos_r[3] > pos_r[2]) ? ((pos_r[3] - pos_r[2]) * s2_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[2];
          else
            block_pos = 5'd31;
          s3_max_slope <= (slope > cmp_slope) ? slope : cmp_slope;
          s3_min_block <= block_pos;
        end
        // Stage 4 (building 4)
        s4_has_tx <= tx_mask_r[4];
        begin
          reg [15:0] slope, cmp_slope;
          reg [4:0] block_pos;
          slope = slope_q12_4(h_r[4], h_r[4], pos_r[4], pos_r[4]);
          cmp_slope = s3_max_slope;
          // Check buildings 0..3
          if (h_r[0] >= (h_r[4] + ((pos_r[4] > pos_r[0]) ? ((pos_r[4] - pos_r[0]) * s3_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[0];
          else if (h_r[1] >= (h_r[4] + ((pos_r[4] > pos_r[1]) ? ((pos_r[4] - pos_r[1]) * s3_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[1];
          else if (h_r[2] >= (h_r[4] + ((pos_r[4] > pos_r[2]) ? ((pos_r[4] - pos_r[2]) * s3_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[2];
          else if (h_r[3] >= (h_r[4] + ((pos_r[4] > pos_r[3]) ? ((pos_r[4] - pos_r[3]) * s3_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[3];
          else
            block_pos = 5'd31;
          s4_max_slope <= (slope > cmp_slope) ? slope : cmp_slope;
          s4_min_block <= block_pos;
        end
        // Stage 5 (building 5)
        s5_has_tx <= tx_mask_r[5];
        begin
          reg [15:0] slope, cmp_slope;
          reg [4:0] block_pos;
          slope = slope_q12_4(h_r[5], h_r[5], pos_r[5], pos_r[5]);
          cmp_slope = s4_max_slope;
          // Check buildings 0..4
          if (h_r[0] >= (h_r[5] + ((pos_r[5] > pos_r[0]) ? ((pos_r[5] - pos_r[0]) * s4_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[0];
          else if (h_r[1] >= (h_r[5] + ((pos_r[5] > pos_r[1]) ? ((pos_r[5] - pos_r[1]) * s4_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[1];
          else if (h_r[2] >= (h_r[5] + ((pos_r[5] > pos_r[2]) ? ((pos_r[5] - pos_r[2]) * s4_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[2];
          else if (h_r[3] >= (h_r[5] + ((pos_r[5] > pos_r[3]) ? ((pos_r[5] - pos_r[3]) * s4_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[3];
          else if (h_r[4] >= (h_r[5] + ((pos_r[5] > pos_r[4]) ? ((pos_r[5] - pos_r[4]) * s4_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[4];
          else
            block_pos = 5'd31;
          s5_max_slope <= (slope > cmp_slope) ? slope : cmp_slope;
          s5_min_block <= block_pos;
        end
        // Stage 6 (building 6)
        s6_has_tx <= tx_mask_r[6];
        begin
          reg [15:0] slope, cmp_slope;
          reg [4:0] block_pos;
          slope = slope_q12_4(h_r[6], h_r[6], pos_r[6], pos_r[6]);
          cmp_slope = s5_max_slope;
          // Check buildings 0..5
          if (h_r[0] >= (h_r[6] + ((pos_r[6] > pos_r[0]) ? ((pos_r[6] - pos_r[0]) * s5_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[0];
          else if (h_r[1] >= (h_r[6] + ((pos_r[6] > pos_r[1]) ? ((pos_r[6] - pos_r[1]) * s5_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[1];
          else if (h_r[2] >= (h_r[6] + ((pos_r[6] > pos_r[2]) ? ((pos_r[6] - pos_r[2]) * s5_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[2];
          else if (h_r[3] >= (h_r[6] + ((pos_r[6] > pos_r[3]) ? ((pos_r[6] - pos_r[3]) * s5_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[3];
          else if (h_r[4] >= (h_r[6] + ((pos_r[6] > pos_r[4]) ? ((pos_r[6] - pos_r[4]) * s5_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[4];
          else if (h_r[5] >= (h_r[6] + ((pos_r[6] > pos_r[5]) ? ((pos_r[6] - pos_r[5]) * s5_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[5];
          else
            block_pos = 5'd31;
          s6_max_slope <= (slope > cmp_slope) ? slope : cmp_slope;
          s6_min_block <= block_pos;
        end
        // Stage 7 (building 7)
        s7_has_tx <= tx_mask_r[7];
        begin
          reg [15:0] slope, cmp_slope;
          reg [4:0] block_pos;
          slope = slope_q12_4(h_r[7], h_r[7], pos_r[7], pos_r[7]);
          cmp_slope = s6_max_slope;
          // Check buildings 0..6
          if (h_r[0] >= (h_r[7] + ((pos_r[7] > pos_r[0]) ? ((pos_r[7] - pos_r[0]) * s6_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[0];
          else if (h_r[1] >= (h_r[7] + ((pos_r[7] > pos_r[1]) ? ((pos_r[7] - pos_r[1]) * s6_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[1];
          else if (h_r[2] >= (h_r[7] + ((pos_r[7] > pos_r[2]) ? ((pos_r[7] - pos_r[2]) * s6_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[2];
          else if (h_r[3] >= (h_r[7] + ((pos_r[7] > pos_r[3]) ? ((pos_r[7] - pos_r[3]) * s6_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[3];
          else if (h_r[4] >= (h_r[7] + ((pos_r[7] > pos_r[4]) ? ((pos_r[7] - pos_r[4]) * s6_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[4];
          else if (h_r[5] >= (h_r[7] + ((pos_r[7] > pos_r[5]) ? ((pos_r[7] - pos_r[5]) * s6_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[5];
          else if (h_r[6] >= (h_r[7] + ((pos_r[7] > pos_r[6]) ? ((pos_r[7] - pos_r[6]) * s6_max_slope >> 4) : 16'h0000)))
            block_pos = pos_r[6];
          else
            block_pos = 5'd31;
          s7_max_slope <= (slope > cmp_slope) ? slope : cmp_slope;
          s7_min_block <= block_pos;
        end

        // Reverse scan pipeline: each stage s (from 7 down to 0) computes nearest blocking to the right
        // Stage 0 corresponds to building 7 in reverse order
        s0_has_tx_r <= tx_mask_r[7];
        begin
          reg [15:0] rev_slope;
          rev_slope = slope_q12_4(h_r[7], h_r[7], pos_r[7], pos_r[7]);
          s0_max_rev_slope <= rev_slope;
          s0_max_right <= 5'd0; // sentinel for none
        end
        // Stage 1 -> building 6
        s1_has_tx_r <= tx_mask_r[6];
        begin
          reg [15:0] rev_slope, cmp_slope;
          reg [4:0] right_max;
          rev_slope = slope_q12_4(h_r[6], h_r[6], pos_r[6], pos_r[6]);
          cmp_slope = s0_max_rev_slope;
          // If building 7 blocks, right_max = pos_r[7]; else use previous right_max
          if (h_r[7] >= (h_r[6] + ((pos_r[6] < pos_r[7]) ? ((pos_r[7] - pos_r[6]) * s0_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[7];
          else
            right_max = s0_max_right;
          s1_max_rev_slope <= (rev_slope > cmp_slope) ? rev_slope : cmp_slope;
          s1_max_right <= right_max;
        end
        // Stage 2 -> building 5
        s2_has_tx_r <= tx_mask_r[5];
        begin
          reg [15:0] rev_slope, cmp_slope;
          reg [4:0] right_max;
          rev_slope = slope_q12_4(h_r[5], h_r[5], pos_r[5], pos_r[5]);
          cmp_slope = s1_max_rev_slope;
          if (h_r[6] >= (h_r[5] + ((pos_r[5] < pos_r[6]) ? ((pos_r[6] - pos_r[5]) * s1_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[6];
          else if (h_r[7] >= (h_r[5] + ((pos_r[5] < pos_r[7]) ? ((pos_r[7] - pos_r[5]) * s1_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[7];
          else
            right_max = s1_max_right;
          s2_max_rev_slope <= (rev_slope > cmp_slope) ? rev_slope : cmp_slope;
          s2_max_right <= right_max;
        end
        // Stage 3 -> building 4
        s3_has_tx_r <= tx_mask_r[4];
        begin
          reg [15:0] rev_slope, cmp_slope;
          reg [4:0] right_max;
          rev_slope = slope_q12_4(h_r[4], h_r[4], pos_r[4], pos_r[4]);
          cmp_slope = s2_max_rev_slope;
          if (h_r[5] >= (h_r[4] + ((pos_r[4] < pos_r[5]) ? ((pos_r[5] - pos_r[4]) * s2_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[5];
          else if (h_r[6] >= (h_r[4] + ((pos_r[4] < pos_r[6]) ? ((pos_r[6] - pos_r[4]) * s2_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[6];
          else if (h_r[7] >= (h_r[4] + ((pos_r[4] < pos_r[7]) ? ((pos_r[7] - pos_r[4]) * s2_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[7];
          else
            right_max = s2_max_right;
          s3_max_rev_slope <= (rev_slope > cmp_slope) ? rev_slope : cmp_slope;
          s3_max_right <= right_max;
        end
        // Stage 4 -> building 3
        s4_has_tx_r <= tx_mask_r[3];
        begin
          reg [15:0] rev_slope, cmp_slope;
          reg [4:0] right_max;
          rev_slope = slope_q12_4(h_r[3], h_r[3], pos_r[3], pos_r[3]);
          cmp_slope = s3_max_rev_slope;
          if (h_r[4] >= (h_r[3] + ((pos_r[3] < pos_r[4]) ? ((pos_r[4] - pos_r[3]) * s3_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[4];
          else if (h_r[5] >= (h_r[3] + ((pos_r[3] < pos_r[5]) ? ((pos_r[5] - pos_r[3]) * s3_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[5];
          else if (h_r[6] >= (h_r[3] + ((pos_r[3] < pos_r[6]) ? ((pos_r[6] - pos_r[3]) * s3_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[6];
          else if (h_r[7] >= (h_r[3] + ((pos_r[3] < pos_r[7]) ? ((pos_r[7] - pos_r[3]) * s3_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[7];
          else
            right_max = s3_max_right;
          s4_max_rev_slope <= (rev_slope > cmp_slope) ? rev_slope : cmp_slope;
          s4_max_right <= right_max;
        end
        // Stage 5 -> building 2
        s5_has_tx_r <= tx_mask_r[2];
        begin
          reg [15:0] rev_slope, cmp_slope;
          reg [4:0] right_max;
          rev_slope = slope_q12_4(h_r[2], h_r[2], pos_r[2], pos_r[2]);
          cmp_slope = s4_max_rev_slope;
          if (h_r[3] >= (h_r[2] + ((pos_r[2] < pos_r[3]) ? ((pos_r[3] - pos_r[2]) * s4_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[3];
          else if (h_r[4] >= (h_r[2] + ((pos_r[2] < pos_r[4]) ? ((pos_r[4] - pos_r[2]) * s4_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[4];
          else if (h_r[5] >= (h_r[2] + ((pos_r[2] < pos_r[5]) ? ((pos_r[5] - pos_r[2]) * s4_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[5];
          else if (h_r[6] >= (h_r[2] + ((pos_r[2] < pos_r[6]) ? ((pos_r[6] - pos_r[2]) * s4_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[6];
          else if (h_r[7] >= (h_r[2] + ((pos_r[2] < pos_r[7]) ? ((pos_r[7] - pos_r[2]) * s4_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[7];
          else
            right_max = s4_max_right;
          s5_max_rev_slope <= (rev_slope > cmp_slope) ? rev_slope : cmp_slope;
          s5_max_right <= right_max;
        end
        // Stage 6 -> building 1
        s6_has_tx_r <= tx_mask_r[1];
        begin
          reg [15:0] rev_slope, cmp_slope;
          reg [4:0] right_max;
          rev_slope = slope_q12_4(h_r[1], h_r[1], pos_r[1], pos_r[1]);
          cmp_slope = s5_max_rev_slope;
          if (h_r[2] >= (h_r[1] + ((pos_r[1] < pos_r[2]) ? ((pos_r[2] - pos_r[1]) * s5_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[2];
          else if (h_r[3] >= (h_r[1] + ((pos_r[1] < pos_r[3]) ? ((pos_r[3] - pos_r[1]) * s5_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[3];
          else if (h_r[4] >= (h_r[1] + ((pos_r[1] < pos_r[4]) ? ((pos_r[4] - pos_r[1]) * s5_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[4];
          else if (h_r[5] >= (h_r[1] + ((pos_r[1] < pos_r[5]) ? ((pos_r[5] - pos_r[1]) * s5_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[5];
          else if (h_r[6] >= (h_r[1] + ((pos_r[1] < pos_r[6]) ? ((pos_r[6] - pos_r[1]) * s5_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[6];
          else if (h_r[7] >= (h_r[1] + ((pos_r[1] < pos_r[7]) ? ((pos_r[7] - pos_r[1]) * s5_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[7];
          else
            right_max = s5_max_right;
          s6_max_rev_slope <= (rev_slope > cmp_slope) ? rev_slope : cmp_slope;
          s6_max_right <= right_max;
        end
        // Stage 7 -> building 0
        s7_has_tx_r <= tx_mask_r[0];
        begin
          reg [15:0] rev_slope, cmp_slope;
          reg [4:0] right_max;
          rev_slope = slope_q12_4(h_r[0], h_r[0], pos_r[0], pos_r[0]);
          cmp_slope = s6_max_rev_slope;
          if (h_r[1] >= (h_r[0] + ((pos_r[0] < pos_r[1]) ? ((pos_r[1] - pos_r[0]) * s6_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[1];
          else if (h_r[2] >= (h_r[0] + ((pos_r[0] < pos_r[2]) ? ((pos_r[2] - pos_r[0]) * s6_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[2];
          else if (h_r[3] >= (h_r[0] + ((pos_r[0] < pos_r[3]) ? ((pos_r[3] - pos_r[0]) * s6_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[3];
          else if (h_r[4] >= (h_r[0] + ((pos_r[0] < pos_r[4]) ? ((pos_r[4] - pos_r[0]) * s6_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[4];
          else if (h_r[5] >= (h_r[0] + ((pos_r[0] < pos_r[5]) ? ((pos_r[5] - pos_r[0]) * s6_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[5];
          else if (h_r[6] >= (h_r[0] + ((pos_r[0] < pos_r[6]) ? ((pos_r[6] - pos_r[0]) * s6_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[6];
          else if (h_r[7] >= (h_r[0] + ((pos_r[0] < pos_r[7]) ? ((pos_r[7] - pos_r[0]) * s6_max_rev_slope >> 4) : 16'h0000)))
            right_max = pos_r[7];
          else
            right_max = s6_max_right;
          s7_max_rev_slope <= (rev_slope > cmp_slope) ? rev_slope : cmp_slope;
          s7_max_right <= right_max;
        end

        // At the end of the pipeline (after 8 cycles), emit coverage
        // We use the outputs of Stage 7 to mark coverage for each building that has a transmitter
        // Building 0 (from reverse stage 7)
        if (s7_has_tx_r) begin
          reg [4:0] R, L;
          R = (s7_max_right == 5'd0) ? city_len_r : s7_max_right;
          L = pos_r[0];
          if (R > L) mark_coverage(L, R);
        end
        // Building 1 (from reverse stage 6)
        if (s6_has_tx_r) begin
          reg [4:0] R, L;
          R = (s6_max_right == 5'd0) ? city_len_r : s6_max_right;
          L = pos_r[1];
          if (R > L) mark_coverage(L, R);
        end
        // Building 2 (from reverse stage 5)
        if (s5_has_tx_r) begin
          reg [4:0] R, L;
          R = (s5_max_right == 5'd0) ? city_len_r : s5_max_right;
          L = pos_r[2];
          if (R > L) mark_coverage(L, R);
        end
        // Building 3 (from reverse stage 4)
        if (s4_has_tx_r) begin
          reg [4:0] R, L;
          R = (s4_max_right == 5'd0) ? city_len_r : s4_max_right;
          L = pos_r[3];
          if (R > L) mark_coverage(L, R);
        end
        // Building 4 (from reverse stage 3)
        if (s3_has_tx_r) begin
          reg [4:0] R, L;
          R = (s3_max_right == 5'd0) ? city_len_r : s3_max_right;
          L = pos_r[4];
          if (R > L) mark_coverage(L, R);
        end
        // Building 5 (from reverse stage 2)
        if (s2_has_tx_r) begin
          reg [4:0] R, L;
          R = (s2_max_right == 5'd0) ? city_len_r : s2_max_right;
          L = pos_r[5];
          if (R > L) mark_coverage(L, R);
        end
        // Building 6 (from reverse stage 1)
        if (s1_has_tx_r) begin
          reg [4:0] R, L;
          R = (s1_max_right == 5'd0) ? city_len_r : s1_max_right;
          L = pos_r[6];
          if (R > L) mark_coverage(L, R);
        end
        // Building 7 (from reverse stage 0)
        if (s0_has_tx_r) begin
          reg [4:0] R, L;
          R = (s0_max_right == 5'd0) ? city_len_r : s0_max_right;
          L = pos_r[7];
          if (R > L) mark_coverage(L, R);
        end

        // Sum marked coverage units at the same pipeline boundary (after 8 cycles)
        // We do this continuously, but valid result is 16 cycles after start; done is asserted then.
        covered_units <= $countones(cov_units);
        sum_scaled <= {covered_units, 4'b0000}; // Q12.4: units * 16

        // Validity control: 16 cycles after start
        if (start) begin
          done <= 1'b0;
          coverage_length <= 16'h0000;
        end else begin
          // After 16 cycles, done=1 and coverage_length holds the final value
          done <= 1'b1;
          coverage_length <= sum_scaled;
        end
      end
    end
  end

endmodule