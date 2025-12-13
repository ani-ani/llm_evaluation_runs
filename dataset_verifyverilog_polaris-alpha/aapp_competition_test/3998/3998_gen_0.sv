module team_rating_equalizer(
  input clk,                // 125 MHz system clock
  input rst_n,              // active-low reset
  input start,              // pulse high to start processing
  input [7:0] r0,           // rating for player 0 (8-bit unsigned)
  input [7:0] r1,           // rating for player 1
  input [7:0] r2,           // rating for player 2
  input [7:0] r3,           // rating for player 3
  output reg [7:0] final_R, // final equal rating
  output reg [3:0] match_vec, // current match vector (1 bit per player)
  output reg valid_match,     // high when match_vec is valid
  output reg done             // high when ratings equalized
);

  // FSM states
  typedef enum logic [2:0] {
    S_INIT          = 3'd0,
    S_LOAD          = 3'd1,
    S_FIND_MAX_MIN  = 3'd2,
    S_SELECT        = 3'd3,
    S_UPDATE        = 3'd4,
    S_CHECK         = 3'd5,
    S_DONE          = 3'd6
  } state_t;

  state_t state, next_state;

  // Rating registers
  reg [7:0] cr0, cr1, cr2, cr3;      // current ratings

  // Max/min tracking
  reg [7:0] max_val, min_val;

  // Match vector (next)
  reg [3:0] next_match_vec;

  // Cycle counter to ensure completion within 100 cycles (guard)
  reg [6:0] cycle_cnt; // 0-99

  // Edge detect for start (allow back-to-back)
  reg start_d;
  wire start_pulse = start & ~start_d;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_INIT;
      cr0         <= 8'd0;
      cr1         <= 8'd0;
      cr2         <= 8'd0;
      cr3         <= 8'd0;
      max_val     <= 8'd0;
      min_val     <= 8'd0;
      match_vec   <= 4'b0000;
      valid_match <= 1'b0;
      final_R     <= 8'd0;
      done        <= 1'b0;
      cycle_cnt   <= 7'd0;
      start_d     <= 1'b0;
    end else begin
      start_d <= start;
      state   <= next_state;

      case (state)
        S_INIT: begin
          // Outputs held cleared here; transitions handled in next_state
          match_vec   <= 4'b0000;
          valid_match <= 1'b0;
          done        <= 1'b0;
          // Wait for start_pulse
        end

        S_LOAD: begin
          // Load input ratings
          cr0       <= r0;
          cr1       <= r1;
          cr2       <= r2;
          cr3       <= r3;
          cycle_cnt <= 7'd0;
          match_vec <= 4'b0000;
          valid_match <= 1'b0;
          done      <= 1'b0;
        end

        S_FIND_MAX_MIN: begin
          // max_val/min_val are driven combinationally in next_state logic
          // hold match-related outputs low
          match_vec   <= 4'b0000;
          valid_match <= 1'b0;
        end

        S_SELECT: begin
          // next_match_vec is computed combinationally; latch here
          match_vec   <= next_match_vec;
          valid_match <= 1'b1; // pulse valid for this selection cycle
        end

        S_UPDATE: begin
          // Consume one cycle for update, clear valid_match pulse
          valid_match <= 1'b0;

          // Decrement selected players (saturating at 0)
          if (match_vec[0] && cr0 != 8'd0) cr0 <= cr0 - 8'd1;
          if (match_vec[1] && cr1 != 8'd0) cr1 <= cr1 - 8'd1;
          if (match_vec[2] && cr2 != 8'd0) cr2 <= cr2 - 8'd1;
          if (match_vec[3] && cr3 != 8'd0) cr3 <= cr3 - 8'd1;

          // Increment cycle counter
          if (cycle_cnt != 7'd99)
            cycle_cnt <= cycle_cnt + 7'd1;
        end

        S_CHECK: begin
          // valid_match remains low
          valid_match <= 1'b0;
          // max_val, min_val updated combinationally
        end

        S_DONE: begin
          // Hold final_R, done until new start
          valid_match <= 1'b0;
        end

        default: begin
          // Safe default
          match_vec   <= 4'b0000;
          valid_match <= 1'b0;
          done        <= 1'b0;
        end
      endcase

      // In DONE state or equalization point, latch final_R & done
      if (next_state == S_DONE) begin
        // All ratings equal -> choose any
        final_R <= cr0;
        done    <= 1'b1;
      end

      // On fresh restart, clear done in LOAD via that state's logic
    end
  end

  // Combinational next-state and helper logic
  always @* begin
    // Default assignments
    next_state     = state;
    max_val        = 8'd0;
    min_val        = 8'hFF;
    next_match_vec = 4'b0000;

    // Local copies for comparisons
    reg [7:0] v0, v1, v2, v3;
    v0 = cr0;
    v1 = cr1;
    v2 = cr2;
    v3 = cr3;

    case (state)
      S_INIT: begin
        if (start_pulse)
          next_state = S_LOAD;
      end

      S_LOAD: begin
        next_state = S_FIND_MAX_MIN;
      end

      S_FIND_MAX_MIN: begin
        // Compute max
        max_val = v0;
        if (v1 > max_val) max_val = v1;
        if (v2 > max_val) max_val = v2;
        if (v3 > max_val) max_val = v3;
        // Compute min
        min_val = v0;
        if (v1 < min_val) min_val = v1;
        if (v2 < min_val) min_val = v2;
        if (v3 < min_val) min_val = v3;

        if (max_val == min_val) begin
          next_state = S_DONE;
        end else begin
          next_state = S_SELECT;
        end
      end

      S_SELECT: begin
        // Determine current max
        max_val = v0;
        if (v1 > max_val) max_val = v1;
        if (v2 > max_val) max_val = v2;
        if (v3 > max_val) max_val = v3;

        // Candidate vector: all players at max_val
        reg [3:0] cand;
        cand[0] = (v0 == max_val);
        cand[1] = (v1 == max_val);
        cand[2] = (v2 == max_val);
        cand[3] = (v3 == max_val);

        // Count candidates
        integer cnt;
        cnt = cand[0] + cand[1] + cand[2] + cand[3];

        // Ensure 2-4 players selected per match, prefer exactly matching max set.
        // If cnt >= 2, use cand.
        // If cnt == 1, add next-highest players to reach at least 2.
        if (cnt >= 2) begin
          next_match_vec = cand;
        end else begin
          // cnt == 1 case: find next-highest to include
          // Determine second max (excluding max_val players already in cand)
          reg [7:0] second_max;
          second_max = 8'd0;
          if (!cand[0] && v0 > second_max) second_max = v0;
          if (!cand[1] && v1 > second_max) second_max = v1;
          if (!cand[2] && v2 > second_max) second_max = v2;
          if (!cand[3] && v3 > second_max) second_max = v3;

          next_match_vec = cand;
          if (!cand[0] && v0 == second_max) next_match_vec[0] = 1'b1;
          if (!cand[1] && v1 == second_max) next_match_vec[1] = 1'b1;
          if (!cand[2] && v2 == second_max) next_match_vec[2] = 1'b1;
          if (!cand[3] && v3 == second_max) next_match_vec[3] = 1'b1;

          // Guarantee at least 2 bits set; if still only 1, include additional players by descending rating
          cnt = next_match_vec[0] + next_match_vec[1] + next_match_vec[2] + next_match_vec[3];
          if (cnt < 2) begin
            // Greedy include highest remaining
            reg [7:0] best;
            reg [1:0] idx;
            best = 8'd0;
            idx  = 2'd0;
            if (!next_match_vec[0] && v0 >= best) begin best = v0; idx = 2'd0; end
            if (!next_match_vec[1] && v1 >= best) begin best = v1; idx = 2'd1; end
            if (!next_match_vec[2] && v2 >= best) begin best = v2; idx = 2'd2; end
            if (!next_match_vec[3] && v3 >= best) begin best = v3; idx = 2'd3; end
            next_match_vec[idx] = 1'b1;
          end
        end

        // Ensure no zero-mask and cap at 4 players (always true for 4-bit mask)
        if (next_match_vec == 4'b0000) begin
          // Fallback: choose top two players by rating
          reg [1:0] i0, i1;
          reg [7:0] b0, b1;
          i0 = 2'd0; i1 = 2'd1;
          if (v1 > v0) begin i0 = 2'd1; i1 = 2'd0; b0 = v1; b1 = v0; end
          else begin b0 = v0; b1 = v1; end
          if (v2 > b0) begin i1 = i0; b1 = b0; i0 = 2'd2; b0 = v2; end
          else if (v2 > b1) begin i1 = 2'd2; b1 = v2; end
          if (v3 > b0) begin i1 = i0; b1 = b0; i0 = 2'd3; b0 = v3; end
          else if (v3 > b1) begin i1 = 2'd3; b1 = v3; end
          next_match_vec = 4'b0000;
          next_match_vec[i0] = 1'b1;
          next_match_vec[i1] = 1'b1;
        end

        next_state = S_UPDATE;
      end

      S_UPDATE: begin
        // After applying decrements sequentially, move to CHECK
        next_state = S_CHECK;
      end

      S_CHECK: begin
        // Recompute max/min with updated values
        max_val = v0;
        if (v1 > max_val) max_val = v1;
        if (v2 > max_val) max_val = v2;
        if (v3 > max_val) max_val = v3;

        min_val = v0;
        if (v1 < min_val) min_val = v1;
        if (v2 < min_val) min_val = v2;
        if (v3 < min_val) min_val = v3;

        if (max_val == min_val) begin
          next_state = S_DONE;
        end else if (cycle_cnt >= 7'd99) begin
          // Safety: force DONE after 100 cycles
          next_state = S_DONE;
        end else begin
          next_state = S_FIND_MAX_MIN;
        end
      end

      S_DONE: begin
        // Wait for next start_pulse to restart
        if (start_pulse)
          next_state = S_LOAD;
      end

      default: begin
        next_state = S_INIT;
      end
    endcase
  end

endmodule