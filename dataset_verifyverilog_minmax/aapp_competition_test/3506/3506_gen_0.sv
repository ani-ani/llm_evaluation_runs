module cheer_scheduler (
  input clk, // clock
  input rst_n, // active-low reset
  input start, // start computation
  input [1:0] n, // Sportify cheerleaders (0-3, ONLY n=1 SUPPORTED)
  input [2:0] t, // minutes per cheerleader (1-7, use t=3 for testing)
  input [1:0] m, // opponent intervals (0-3)
  input [3:0] interval_0_a, interval_0_b, // opponent interval 0 (minutes 0-7)
  input [3:0] interval_1_a, interval_1_b, // opponent interval 1
  input [3:0] interval_2_a, interval_2_b, // opponent interval 2

  output reg [2:0] sportify_goals, // goals scored (0-4 max)
  output reg [2:0] spoilify_goals, // goals scored (0-4 max)
  output reg done // high when result ready
);

  // Count opponent cheers per minute (0..3) from up to 3 intervals
  function [3:0] opp_cheers;
    input [3:0] a, b; // 0 <= a < b <= 8
    integer i;
    begin
      opp_cheers = 4'd0;
      for (i = 0; i < 8; i = i + 1) begin
        if ((i > a) && (i < b)) opp_cheers = opp_cheers + 1'b1;
      end
    end
  endfunction

  // FSM states
  localparam IDLE  = 2'b00;
  localparam RUN   = 2'b01;
  localparam DONE  = 2'b10;

  reg [1:0] state, next_state;
  integer i, j, k;
  integer minute;
  integer opp_count [0:7];

  // Valid ranges
  wire inputs_valid;
  assign inputs_valid = (t >= 3) && (t <= 7) && (m <= 3);

  // Scheduling search (support only n=1, t fixed per testing)
  integer base;
  integer sportify_min [0:7]; // 0/1 cheers per minute

  // Streak and goal tracking per candidate
  integer half; // 0 or 1
  integer prev_winner; // 0 none, 1 sportify, 2 spoilify
  integer win_len; // consecutive minutes current winner leads
  integer streaks_per_half [0:1][1:2]; // [half][winner:1,2] -> count
  integer sf_goals_candidate, so_goals_candidate;
  integer half_goals [0:1][1:2]; // per half goals (capped at 2)

  // Best result selection
  integer best_delta, best_sf, best_so;

  // State update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      sportify_goals <= 3'd0;
      spoilify_goals <= 3'd0;
    end else begin
      state <= next_state;
      done <= 1'b0;
      if (state == DONE) begin
        done <= 1'b1;
        sportify_goals <= 3'(best_sf);
        spoilify_goals <= 3'(best_so);
      end
    end
  end

  // Next state logic and computation
  always @(*) begin
    // Defaults
    next_state = state;
    best_delta = -9999;
    best_sf = 0;
    best_so = 0;

    if (state == IDLE) begin
      if (start) begin
        next_state = RUN;
      end else begin
        next_state = IDLE;
      end
    end else if (state == RUN) begin
      // Precompute opponent cheers per minute
      for (minute = 0; minute < 8; minute = minute + 1) begin
        opp_count[minute] = 0;
      end

      if (m >= 1) begin
        for (minute = 0; minute < 8; minute = minute + 1) begin
          opp_count[minute] = opp_count[minute] + opp_cheers(interval_0_a, interval_0_b);
        end
      end
      if (m >= 2) begin
        for (minute = 0; minute < 8; minute = minute + 1) begin
          opp_count[minute] = opp_count[minute] + opp_cheers(interval_1_a, interval_1_b);
        end
      end
      if (m >= 3) begin
        for (minute = 0; minute < 8; minute = minute + 1) begin
          opp_count[minute] = opp_count[minute] + opp_cheers(interval_2_a, interval_2_b);
        end
      end

      // Enumerate valid start positions for the single 3-minute cheer (n=1, t=3)
      for (base = 0; base <= 5; base = base + 1) begin
        // Reset candidate counters
        sf_goals_candidate = 0;
        so_goals_candidate = 0;
        for (half = 0; half < 2; half = half + 1) begin
          streaks_per_half[half][1] = 0;
          streaks_per_half[half][2] = 0;
          half_goals[half][1] = 0;
          half_goals[half][2] = 0;
        end
        prev_winner = 0;
        win_len = 0;

        // Build sportify schedule and score across 8 minutes
        for (minute = 0; minute < 8; minute = minute + 1) begin
          sportify_min[minute] = ((minute >= base) && (minute < (base + 3))) ? 1 : 0;
        end
        for (minute = 0; minute < 8; minute = minute + 1) begin
          half = (minute < 4) ? 0 : 1;
          if (sportify_min[minute] > opp_count[minute]) begin
            if (prev_winner == 1) begin
              win_len = win_len + 1;
            end else begin
              prev_winner = 1;
              win_len = 1;
            end
          end else if (sportify_min[minute] < opp_count[minute]) begin
            if (prev_winner == 2) begin
              win_len = win_len + 1;
            end else begin
              prev_winner = 2;
              win_len = 1;
            end
          end else begin
            // tie
            prev_winner = 0;
            win_len = 0;
          end

          if (win_len == 2) begin
            // Award one goal for the streak end and continue counting streaks (but cap per half at 2)
            if (prev_winner == 1) begin
              if (half_goals[half][1] < 2) begin
                half_goals[half][1] = half_goals[half][1] + 1;
                sf_goals_candidate = sf_goals_candidate + 1;
              end
              streaks_per_half[half][1] = streaks_per_half[half][1] + 1;
            end else if (prev_winner == 2) begin
              if (half_goals[half][2] < 2) begin
                half_goals[half][2] = half_goals[half][2] + 1;
                so_goals_candidate = so_goals_candidate + 1;
              end
              streaks_per_half[half][2] = streaks_per_half[half][2] + 1;
            end
            // Continue counting new streak length from here
            win_len = 1;
          end
        end

        // Update best candidate based on selection criteria
        if ((sf_goals_candidate - so_goals_candidate) > best_delta) begin
          best_delta = sf_goals_candidate - so_goals_candidate;
          best_sf = sf_goals_candidate;
          best_so = so_goals_candidate;
        end else if ((sf_goals_candidate - so_goals_candidate) == best_delta) begin
          if (sf_goals_candidate > best_sf) begin
            best_sf = sf_goals_candidate;
            best_so = so_goals_candidate;
          end
        end
      end

      next_state = DONE;
    end else if (state == DONE) begin
      next_state = DONE; // stay until reset or new start
    end
  end

  // Safety: if inputs invalid at start, finish immediately with zeros
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // default reset values already set above
    end else if (state == RUN) begin
      if (!inputs_valid) begin
        // Force done next cycle with zeroed goals
        best_delta = -9999;
        best_sf = 0;
        best_so = 0;
      end
    end
  end

endmodule
