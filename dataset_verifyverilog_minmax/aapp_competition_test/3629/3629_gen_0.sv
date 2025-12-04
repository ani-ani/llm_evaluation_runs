module boar_charge_probability (
  input clk,
  input rst_n,
  input start,
  input [2:0] tree_count,
  input [15:0] b,
  input [15:0] d,
  input [15:0] tree_x [0:7],
  input [15:0] tree_y [0:7],
  input [15:0] tree_r [0:7],
  output reg [31:0] prob_q16,
  output reg done
);

  // Constants
  localparam [31:0] PI_Q16 = 32'h0003243F;         // 3.1415926535 in Q16.16
  localparam [31:0] TWO_PI_Q16 = 32'h0006487E;     // 2*PI in Q16.16
  localparam [31:0] RAD_TO_DEG_Q16 = 32'h03993A1;  // 180/pi in Q16.16 (approx 0x03993A1)
  localparam [31:0] ONE_Q16 = 32'h00010000;        // 1.0 in Q16.16
  localparam [31:0] MAX_PROB_Q16 = 32'h00010000;   // clamp to 1.0

  // State machine
  typedef enum logic [4:0] {
    S_IDLE    = 5'd0,
    S_T0      = 5'd1,
    S_T1      = 5'd2,
    S_T2      = 5'd3,
    S_T3      = 5'd4,
    S_T4      = 5'd5,
    S_T5      = 5'd6,
    S_T6      = 5'd7,
    S_T7      = 5'd8,
    S_MERGE1  = 5'd9,
    S_MERGE2  = 5'd10,
    S_MERGE3  = 5'd11,
    S_MERGE4  = 5'd12,
    S_MERGE5  = 5'd13,
    S_MERGE6  = 5'd14,
    S_MERGE7  = 5'd15,
    S_DONE    = 5'd16
  } state_t;
  state_t state, next_state;

  // Iteration/merge indices and counters
  reg [2:0] i_cur;           // current tree index (0..7)
  reg [3:0] merge_i;         // merge scan index (0..7)
  reg [2:0] block_cnt;       // number of blocked intervals (0..8)
  reg [2:0] block_cnt_next;
  reg [3:0] scan_i;          // merge scan index (0..7)

  // Per-tree working values (registered)
  reg signed [15:0] x0, y0;
  reg signed [31:0] x0_sq, y0_sq, sum_sq;
  reg [15:0] b_cur, d_cur, r0;
  reg [15:0] effective_R;
  reg [31:0] R_sq, R2_sq, d2_sq, d_plus_b_sq;
  reg [31:0] x0_sq_reg, y0_sq_reg, sum_sq_reg;
  reg [15:0] effective_R_reg, r0_reg;
  reg [31:0] R_sq_reg, R2_sq_reg, d2_sq_reg, d_plus_b_sq_reg;

  // Angular interval in Q16.16 radians
  reg [31:0] theta_min_q16, theta_max_q16; // signed Q16.16
  reg [31:0] start_rad_q16, end_rad_q16;   // signed Q16.16
  reg has_interval;                        // 1 if this tree blocks a non-empty interval

  // Blocked intervals storage (start,end) in Q16.16 signed radians
  reg [31:0] block_start [0:7];
  reg [31:0] block_end   [0:7];
  reg [31:0] block_start_next [0:7];
  reg [31:0] block_end_next   [0:7];

  // Merge temp vars
  reg [31:0] cur_s, cur_e;
  reg [31:0] merged_s, merged_e;
  reg [31:0] total_blocked_rad_q16; // signed Q16.16 radians sum
  reg [31:0] total_blocked_deg_q16; // signed Q16.16 degrees sum
  reg [31:0] prob_q16_calc;

  // Helper functions
  function [31:0] atan2_q16 (
    input signed [15:0] y,
    input signed [15:0] x
  );
    // Returns angle in [-pi, pi] in Q16.16 radians using a 2-quadrant arctan approximation
    // Polynomial-based (no latency), suitable for steady-state sequential updates
    // PI_Q16 = 0x3243F, HALF_PI_Q16 = 0x1921F (approx)
    logic signed [16:0] ax, ay;
    logic signed [31:0] t, t2, t3, t5, poly, ang;
    logic signed [31:0] PI_Q16_local, HALF_PI_Q16_local;
    begin
      PI_Q16_local = 32'h0003243F;         // pi
      HALF_PI_Q16_local = 32'h0001921F;    // pi/2 (approx)
      ax = $signed({1'b0, x}); // zero-extend to 17-bit
      ay = $signed({1'b0, y}); // zero-extend to 17-bit
      // Map to first quadrant: a = atan(|y|/|x|)
      t = (ax == 0) ? 32'h7FFFFFFF : $signed({ay,16'h0000}) / ax; // t = y/x in Q16.16-ish (scaled)
      // Clamp t
      if (t >  32'h00010000) t = 32'h00010000;
      if (t < -32'h00010000) t = -32'h00010000;
      t2 = (t * t) >> 16; // t^2 in Q16.16
      t3 = (t2 * t) >> 16; // t^3
      t5 = (t3 * t2) >> 16; // t^5
      // Polynomial: a ≈ t - t^3/3 + t^5/5 (good for |t| <= 1)
      poly = t - (t3 / 3) + (t5 / 5);
      // Determine quadrant
      if (x >= 0 && y >= 0) begin
        ang = poly;                         // Q1
      end else if (x < 0 && y >= 0) begin
        ang = PI_Q16_local - poly;          // Q2
      end else if (x < 0 && y < 0) begin
        ang = -PI_Q16_local + poly;         // Q3
      end else begin // x >= 0 && y < 0
        ang = -poly;                        // Q4
      end
      // Normalize to [-pi, pi]
      if (ang > PI_Q16_local)      ang = ang - TWO_PI_Q16;
      else if (ang < -PI_Q16_local) ang = ang + TWO_PI_Q16;
      atan2_q16 = ang;
    end
  endfunction

  function [31:0] angle_diff_q16 (
    input [31:0] a, // Q16.16 signed
    input [31:0] b  // Q16.16 signed
  );
    // Returns (a - b) normalized to (-pi, pi]
    logic signed [31:0] diff;
    begin
      diff = $signed(a) - $signed(b);
      if (diff > 32'h0003243F) diff = diff - TWO_PI_Q16;  // > pi
      if (diff < -32'h0003243F) diff = diff + TWO_PI_Q16; // <= -pi
      angle_diff_q16 = diff;
    end
  endfunction

  // State update and next-state logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      i_cur <= 3'd0;
      merge_i <= 4'd0;
      block_cnt <= 3'd0;
      scan_i <= 4'd0;
      done <= 1'b0;
      prob_q16 <= 32'd0;
      // Clear intervals
      for (int k = 0; k < 8; k++) begin
        block_start[k] <= 32'd0;
        block_end[k]   <= 32'd0;
      end
      total_blocked_rad_q16 <= 32'd0;
      total_blocked_deg_q16 <= 32'd0;
    end else begin
      state <= next_state;

      // Defaults (will be overridden per state)
      block_cnt_next <= block_cnt;
      done <= 1'b0;
      prob_q16 <= prob_q16;

      // Capture inputs for the current tree when entering its processing state
      case (state)
        S_T0, S_T1, S_T2, S_T3, S_T4, S_T5, S_T6, S_T7: begin
          i_cur <= state[2:0]; // encode 0..7
        end
        default: ;
      endcase

      // For each tree we register values needed in subsequent cycles
      case (next_state)
        S_T0, S_T1, S_T2, S_T3, S_T4, S_T5, S_T6, S_T7: begin
          x0 <= tree_x[next_state[2:0]];
          y0 <= tree_y[next_state[2:0]];
          r0 <= tree_r[next_state[2:0]];
          b_cur <= b;
          d_cur <= d;
        end
        default: begin
          x0 <= x0;
          y0 <= y0;
          r0 <= r0;
          b_cur <= b_cur;
          d_cur <= d_cur;
        end
      endcase

      // Per-tree pipeline
      case (state)
        S_T0, S_T1, S_T2, S_T3, S_T4, S_T5, S_T6, S_T7: begin
          // Cycle 1: compute distance squares
          x0_sq <= $signed(x0) * $signed(x0);
          y0_sq <= $signed(y0) * $signed(y0);
          sum_sq <= (x0_sq + y0_sq) >> 0; // keep 32-bit
          // compute R = d + b + r_i
          effective_R <= d + b + r0;
          R_sq <= $unsigned(effective_R) * $unsigned(effective_R);
          // also compute (d + b)^2 for the skip condition
          d_plus_b_sq <= $unsigned(d + b) * $unsigned(d + b);
          R2_sq <= R_sq;
          d2_sq <= d_plus_b_sq;
        end
        S_T0, S_T1, S_T2, S_T3, S_T4, S_T5, S_T6, S_T7: begin
          // already registered in previous cycle
          x0_sq_reg <= x0_sq;
          y0_sq_reg <= y0_sq;
          sum_sq_reg <= sum_sq;
          effective_R_reg <= effective_R;
          R_sq_reg <= R_sq;
          d_plus_b_sq_reg <= d_plus_b_sq;
          R2_sq_reg <= R2_sq;
          d2_sq_reg <= d2_sq;
        end
        default: begin
          x0_sq_reg <= x0_sq_reg;
          y0_sq_reg <= y0_sq_reg;
          sum_sq_reg <= sum_sq_reg;
          effective_R_reg <= effective_R_reg;
          R_sq_reg <= R_sq_reg;
          d_plus_b_sq_reg <= d_plus_b_sq_reg;
          R2_sq_reg <= R2_sq_reg;
          d2_sq_reg <= d2_sq_reg;
        end
      endcase

      // Cycle 2: decide skip/impact and compute theta0
      case (state)
        S_T0, S_T1, S_T2, S_T3, S_T4, S_T5, S_T6, S_T7: begin
          // Decide skip: if (x^2 + y^2) > (d + b + r)^2
          if (sum_sq_reg > R2_sq_reg) begin
            has_interval <= 1'b0;
            theta_min_q16 <= 32'd0;
            theta_max_q16 <= 32'd0;
          end else begin
            // compute theta0 = atan2(y, x) in Q16.16
            theta_min_q16 <= atan2_q16(y0, x0); // reuse theta_min_q16 as temp storage of theta0
            has_interval <= 1'b1; // provisional, will finalize in next cycle
          end
        end
        default: begin
          theta_min_q16 <= theta_min_q16; // keep
          has_interval <= has_interval;
        end
      endcase

      // Cycle 3: compute angular half-width and interval; write interval if valid
      case (state)
        S_T0, S_T1, S_T2, S_T3, S_T4, S_T5, S_T6, S_T7: begin
          if (has_interval) begin
            // alpha = asin( R / sqrt(x^2 + y^2) )
            // R in 16-bit, sqrt in 16-bit (approx) -> ratio in [0,1], use polynomial for asin
            // Compute approx sqrt as unsigned magnitude in 16-bit
            logic [15:0] approx_mag;
            logic [31:0] ratio, ratio_sq, ratio_sq3, ratio_sq5, asin_poly, two_alpha;
            logic [31:0] alpha;
            approx_mag = (x0_sq_reg > y0_sq_reg) ? $unsigned($sqrt(x0_sq_reg)) : $unsigned($sqrt(y0_sq_reg));
            // Guard: if approx_mag == 0, set ratio to max to avoid div-by-zero (angle -> +/- pi/2)
            ratio = (approx_mag == 16'd0) ? 32'h00010000 : ({1'b0, effective_R_reg} << 16) / {1'b0, approx_mag};
            if (ratio > 32'h00010000) ratio = 32'h00010000; // clamp
            // asin(r) ≈ r + r^3/6 + 3 r^5 / 40 (Q16.16)
            ratio_sq   = (ratio * ratio) >> 16;
            ratio_sq3  = (ratio_sq * ratio) >> 16;
            ratio_sq5  = (ratio_sq3 * ratio_sq) >> 16;
            asin_poly  = ratio + (ratio_sq3 / 6) + ((3 * ratio_sq5) / 40);
            alpha      = asin_poly; // Q16.16 radians
            two_alpha  = (alpha << 1);
            // compute start/end = theta0 +/- alpha
            cur_s = theta_min_q16 - two_alpha;
            cur_e = theta_min_q16 + two_alpha;
            // wrap to [-pi, pi]
            if (cur_s < -PI_Q16) cur_s = cur_s + TWO_PI_Q16;
            if (cur_e >  PI_Q16) cur_e = cur_e - TWO_PI_Q16;
            // write interval into list (unsorted for now; will be sorted in merge)
            block_start[block_cnt] <= cur_s;
            block_end[block_cnt]   <= cur_e;
            block_cnt_next <= block_cnt + 1'b1;
          end else begin
            block_cnt_next <= block_cnt;
          end
        end
        default: begin
          block_cnt_next <= block_cnt;
        end
      endcase

      // Merge (single-pass bubble-like) and accumulate total blocked radians
      case (next_state)
        S_MERGE1: begin
          // Init scan
          merge_i <= 4'd0;
          block_cnt_next <= block_cnt;
          for (int k = 0; k < 8; k++) begin
            block_start_next[k] <= block_start[k];
            block_end_next[k]   <= block_end[k];
          end
        end
        S_MERGE2, S_MERGE3, S_MERGE4, S_MERGE5, S_MERGE6, S_MERGE7: begin
          if (merge_i < (block_cnt - 1)) begin
            // Bubble larger to the right if out of order
            if ($signed(block_end_next[merge_i]) > $signed(block_start_next[merge_i+1])) begin
              cur_s = block_start_next[merge_i];
              cur_e = block_end_next[merge_i];
              block_start_next[merge_i]   <= block_start_next[merge_i+1];
              block_end_next[merge_i]     <= block_end_next[merge_i+1];
              block_start_next[merge_i+1] <= cur_s;
              block_end_next[merge_i+1]   <= cur_e;
            end
            merge_i <= merge_i + 1;
            block_cnt_next <= block_cnt;
          end else begin
            merge_i <= merge_i + 1; // finish
            block_cnt_next <= block_cnt;
          end
          // Propagate for next cycle
          for (int k = 0; k < 8; k++) begin
            block_start[k] <= block_start_next[k];
            block_end[k]   <= block_end_next[k];
          end
        end
        default: begin
          // No change
          for (int k = 0; k < 8; k++) begin
            block_start[k] <= block_start_next[k];
            block_end[k]   <= block_end_next[k];
          end
        end
      endcase

      // After sorting, merge overlaps and sum lengths
      case (state)
        S_MERGE7: begin
          // Start merging overlaps
          scan_i <= 4'd0;
          total_blocked_rad_q16 <= 32'd0;
          merged_s <= 32'd0;
          merged_e <= 32'd0;
        end
        S_MERGE7, S_MERGE1, S_MERGE2, S_MERGE3, S_MERGE4, S_MERGE5, S_MERGE6: begin
          if (scan_i < block_cnt) begin
            if (scan_i == 0) begin
              merged_s <= block_start[0];
              merged_e <= block_end[0];
              scan_i <= scan_i + 1;
            end else begin
              if ($signed(block_start[scan_i]) <= $signed(merged_e)) begin
                // Overlap: extend
                if ($signed(block_end[scan_i]) > $signed(merged_e)) begin
                  merged_e <= block_end[scan_i];
                end
                scan_i <= scan_i + 1;
              end else begin
                // No overlap: accumulate current merged interval and start new
                total_blocked_rad_q16 <= total_blocked_rad_q16 + angle_diff_q16(merged_e, merged_s);
                merged_s <= block_start[scan_i];
                merged_e <= block_end[scan_i];
                scan_i <= scan_i + 1;
              end
            end
          end else begin
            // Finish: add last interval
            total_blocked_rad_q16 <= total_blocked_rad_q16 + angle_diff_q16(merged_e, merged_s);
          end
        end
        default: ;
      endcase

      // Compute probability
      case (next_state)
        S_DONE: begin
          // Convert blocked radians to degrees: deg = rad * RAD_TO_DEG_Q16
          total_blocked_deg_q16 <= (total_blocked_rad_q16 * RAD_TO_DEG_Q16) >> 16;
          // Probability = 1 - (blocked_deg / 360)
          // 360 in Q16.16 is 0x39300000
          prob_q16_calc <= ONE_Q16 - ((total_blocked_deg_q16 << 16) / 32'h39300000);
          if (prob_q16_calc > MAX_PROB_Q16) prob_q16_calc <= MAX_PROB_Q16;
          if (prob_q16_calc < 0) prob_q16_calc <= 0;
          prob_q16 <= prob_q16_calc;
          done <= 1'b1;
        end
        default: begin
          prob_q16 <= prob_q16;
          done <= 1'b0;
        end
      endcase

      // Persist counters
      block_cnt <= block_cnt_next;
    end
  end

  // Next-state logic
  always_comb begin
    next_state = S_IDLE;
    case (state)
      S_IDLE:    next_state = start ? S_T0 : S_IDLE;
      S_T0:      next_state = S_T1;
      S_T1:      next_state = S_T2;
      S_T2:      next_state = S_T3;
      S_T3:      next_state = S_T4;
      S_T4:      next_state = S_T5;
      S_T5:      next_state = S_T6;
      S_T6:      next_state = S_T7;
      S_T7:      next_state = S_MERGE1;
      S_MERGE1:  next_state = S_MERGE2;
      S_MERGE2:  next_state = S_MERGE3;
      S_MERGE3:  next_state = S_MERGE4;
      S_MERGE4:  next_state = S_MERGE5;
      S_MERGE5:  next_state = S_MERGE6;
      S_MERGE6:  next_state = S_MERGE7;
      S_MERGE7:  next_state = S_DONE;
      S_DONE:    next_state = S_IDLE;
      default:   next_state = S_IDLE;
    endcase
  end

endmodule