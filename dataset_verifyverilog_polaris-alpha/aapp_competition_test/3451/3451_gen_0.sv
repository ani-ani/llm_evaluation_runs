module min_effort_balancing(
  input clk,
  input rst_n,
  input start,
  input [2:0] k_in,
  input [7:0] seq_bits,
  input [7:0][10:0] costs,
  output reg [10:0] min_effort,
  output reg impossible_flag,
  output reg done
);

  // Internal registers
  reg [3:0]  cycle_cnt;
  reg [2:0]  req_flips;
  reg [3:0]  balance;
  reg [7:0]  candidate_mask;      // bit i = 1 if position i is unexpected ')'
  reg [7:0][10:0] cand_costs;     // extracted candidate costs (only for unexpected ')')

  reg [2:0]  k_latched;

  // Sorting network wires for candidate costs (8 inputs)
  reg  [10:0] s0 [7:0];
  reg  [10:0] s1 [7:0];
  reg  [10:0] s2 [7:0];

  // Selected flip costs and their prefix sums
  reg [10:0] flip_costs [7:0];    // sorted candidate costs (smallest first)
  reg [10:0] prefix_sum [7:0];

  reg [10:0] min_effort_calc;
  reg        impossible_calc;

  // Helper function: 11-bit signed less-than
  function automatic bit less_than_signed_11(input [10:0] a, input [10:0] b);
    begin
      less_than_signed_11 = ($signed(a) < $signed(b));
    end
  endfunction

  // Compare-exchange task (signed, ascending)
  task automatic cmp_exch_signed_11(
    inout [10:0] x,
    inout [10:0] y
  );
    reg [10:0] tx, ty;
    begin
      tx = x;
      ty = y;
      if (!less_than_signed_11(tx, ty)) begin
        x = ty;
        y = tx;
      end
    end
  endtask

  // Sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_cnt       <= 4'd0;
      req_flips       <= 3'd0;
      balance         <= 4'd0;
      candidate_mask  <= 8'd0;
      k_latched       <= 3'd0;
      min_effort      <= 11'd0;
      impossible_flag <= 1'b0;
      done            <= 1'b0;
    end else begin
      if (start) begin
        // Initialize computation on start pulse
        cycle_cnt       <= 4'd0;
        req_flips       <= 3'd0;
        balance         <= 4'd0;
        candidate_mask  <= 8'd0;
        k_latched       <= k_in;
        min_effort      <= 11'd0;
        impossible_flag <= 1'b0;
        done            <= 1'b0;
      end else if (!done) begin
        cycle_cnt <= cycle_cnt + 4'd1;

        // Cycle 0-7: scan sequence, accumulate balance and unexpected ')'
        if (cycle_cnt < 4'd8) begin
          // Index
          case (seq_bits[cycle_cnt])
            1'b0: begin
              // '('
              balance <= balance + 4'd1;
            end
            1'b1: begin
              // ')'
              if (balance != 4'd0) begin
                // matches existing '('
                balance <= balance - 4'd1;
              end else begin
                // unexpected ')', must flip
                req_flips <= req_flips + 3'd1;
                candidate_mask[cycle_cnt] <= 1'b1;
              end
            end
            default: begin
              // treat as ')' safety
              if (balance != 4'd0) begin
                balance <= balance - 4'd1;
              end else begin
                req_flips <= req_flips + 3'd1;
                candidate_mask[cycle_cnt] <= 1'b1;
              end
            end
          endcase
        end

        // Cycle 8: decide impossible or prepare for cost processing
        if (cycle_cnt == 4'd8) begin
          // Copy candidate costs
          cand_costs[0] <= candidate_mask[0] ? costs[0] : 11'sd0;
          cand_costs[1] <= candidate_mask[1] ? costs[1] : 11'sd0;
          cand_costs[2] <= candidate_mask[2] ? costs[2] : 11'sd0;
          cand_costs[3] <= candidate_mask[3] ? costs[3] : 11'sd0;
          cand_costs[4] <= candidate_mask[4] ? costs[4] : 11'sd0;
          cand_costs[5] <= candidate_mask[5] ? costs[5] : 11'sd0;
          cand_costs[6] <= candidate_mask[6] ? costs[6] : 11'sd0;
          cand_costs[7] <= candidate_mask[7] ? costs[7] : 11'sd0;
        end

        // Cycle 9-12: sorting network (combinational in sequential block for clarity)
        if (cycle_cnt == 4'd9) begin
          // Stage 0: load
          s0[0] <= cand_costs[0];
          s0[1] <= cand_costs[1];
          s0[2] <= cand_costs[2];
          s0[3] <= cand_costs[3];
          s0[4] <= cand_costs[4];
          s0[5] <= cand_costs[5];
          s0[6] <= cand_costs[6];
          s0[7] <= cand_costs[7];
        end else if (cycle_cnt == 4'd10) begin
          // Stage 1: pairwise compare-exchange
          s1[0] <= s0[0]; s1[1] <= s0[1];
          s1[2] <= s0[2]; s1[3] <= s0[3];
          s1[4] <= s0[4]; s1[5] <= s0[5];
          s1[6] <= s0[6]; s1[7] <= s0[7];

          cmp_exch_signed_11(s1[0], s1[1]);
          cmp_exch_signed_11(s1[2], s1[3]);
          cmp_exch_signed_11(s1[4], s1[5]);
          cmp_exch_signed_11(s1[6], s1[7]);
        end else if (cycle_cnt == 4'd11) begin
          // Stage 2
          s2[0] <= s1[0]; s2[1] <= s1[1];
          s2[2] <= s1[2]; s2[3] <= s1[3];
          s2[4] <= s1[4]; s2[5] <= s1[5];
          s2[6] <= s1[6]; s2[7] <= s1[7];

          cmp_exch_signed_11(s2[0], s2[2]);
          cmp_exch_signed_11(s2[1], s2[3]);
          cmp_exch_signed_11(s2[4], s2[6]);
          cmp_exch_signed_11(s2[5], s2[7]);
        end else if (cycle_cnt == 4'd12) begin
          // Stage 3 & final merge for 8-input bitonic-like network (simplified)
          flip_costs[0] <= s2[0];
          flip_costs[1] <= s2[1];
          flip_costs[2] <= s2[2];
          flip_costs[3] <= s2[3];
          flip_costs[4] <= s2[4];
          flip_costs[5] <= s2[5];
          flip_costs[6] <= s2[6];
          flip_costs[7] <= s2[7];

          // Additional refining compare-exchanges
          cmp_exch_signed_11(flip_costs[1], flip_costs[2]);
          cmp_exch_signed_11(flip_costs[0], flip_costs[1]);
          cmp_exch_signed_11(flip_costs[2], flip_costs[3]);
          cmp_exch_signed_11(flip_costs[4], flip_costs[5]);
          cmp_exch_signed_11(flip_costs[6], flip_costs[7]);
          cmp_exch_signed_11(flip_costs[5], flip_costs[6]);
          cmp_exch_signed_11(flip_costs[4], flip_costs[5]);
        end

        // Cycle 13: compute prefix sums of sorted candidate costs
        if (cycle_cnt == 4'd13) begin
          prefix_sum[0] <= flip_costs[0];
          prefix_sum[1] <= flip_costs[0] + flip_costs[1];
          prefix_sum[2] <= flip_costs[0] + flip_costs[1] + flip_costs[2];
          prefix_sum[3] <= flip_costs[0] + flip_costs[1] + flip_costs[2] + flip_costs[3];
          prefix_sum[4] <= flip_costs[0] + flip_costs[1] + flip_costs[2] + flip_costs[3] + flip_costs[4];
          prefix_sum[5] <= flip_costs[0] + flip_costs[1] + flip_costs[2] + flip_costs[3] + flip_costs[4] + flip_costs[5];
          prefix_sum[6] <= flip_costs[0] + flip_costs[1] + flip_costs[2] + flip_costs[3] + flip_costs[4] + flip_costs[5] + flip_costs[6];
          prefix_sum[7] <= flip_costs[0] + flip_costs[1] + flip_costs[2] + flip_costs[3] + flip_costs[4] + flip_costs[5] + flip_costs[6] + flip_costs[7];
        end

        // Cycle 14: final decision and output calculation
        if (cycle_cnt == 4'd14) begin
          if (req_flips > k_latched) begin
            impossible_calc <= 1'b1;
            min_effort_calc <= 11'sd0;
          end else begin
            impossible_calc <= 1'b0;
            // Count = k_in - required_flips + 1 (saturate at 0..8)
            if (k_latched >= req_flips) begin
              // Use min(number, 8) index into prefix sums
              // n = k_latched - req_flips + 1
              case (k_latched - req_flips + 3'd1)
                3'd0: min_effort_calc <= 11'sd0;
                3'd1: min_effort_calc <= prefix_sum[0];
                3'd2: min_effort_calc <= prefix_sum[1];
                3'd3: min_effort_calc <= prefix_sum[2];
                3'd4: min_effort_calc <= prefix_sum[3];
                3'd5: min_effort_calc <= prefix_sum[4];
                3'd6: min_effort_calc <= prefix_sum[5];
                3'd7: min_effort_calc <= prefix_sum[6];
                default: min_effort_calc <= prefix_sum[7];
              endcase
            end else begin
              // Should not happen due to earlier check; safe default
              min_effort_calc <= 11'sd0;
            end
          end
        end

        // Cycle 15: latch outputs and set done
        if (cycle_cnt == 4'd15) begin
          impossible_flag <= impossible_calc;
          min_effort      <= min_effort_calc;
          done            <= 1'b1;
        end
      end
    end
  end

endmodule