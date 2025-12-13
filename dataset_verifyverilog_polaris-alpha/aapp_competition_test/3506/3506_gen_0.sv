module cheer_scheduler(
  input  clk,
  input  rst_n,
  input  start,
  input  [1:0] n,
  input  [2:0] t,
  input  [1:0] m,
  input  [3:0] interval_0_a, input [3:0] interval_0_b,
  input  [3:0] interval_1_a, input [3:0] interval_1_b,
  input  [3:0] interval_2_a, input [3:0] interval_2_b,
  output reg [2:0] sportify_goals,
  output reg [2:0] spoilify_goals,
  output reg done
);

  // Assumptions/Notes:
  // - Only n=1 is functionally supported (single cheerleader), but n is accepted.
  // - t is generic (1-7); all valid single-interval schedules (start in [0..8-t]) are evaluated.
  // - m in [0..3] indicates how many opponent intervals are active among interval_0/1/2.
  // - Opponent intervals are [a,b) in minutes 0..8, with a < b; each active interval contributes 1 cheer per minute.
  // - Max opponent cheers per minute is 3.
  // - Game minutes: 0..7 (8 minutes total); halves are [0..3] and [4..7].
  // - For each schedule, Sportify cheers = 1 during its interval, else 0.
  // - Per minute compare Sportify vs opponent counts.
  // - For each half independently, any run of 2 consecutive minutes where one side strictly leads
  //   yields 1 goal for that side (per half, we consider disjoint 2-min windows: (0,1) and (2,3) in H1,
  //   (4,5) and (6,7) in H2). This simplifies to: for each such fixed pair, if both minutes favor
  //   the same team, that team gains 1 goal.
  // - Objective: choose schedule maximizing (sportify_goals - spoilify_goals), then maximizing sportify_goals.
  // - Latency requirement (<=100 cycles) is met via simple sequential evaluation.

  // Internal state machine
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_SETUP_OPP = 3'd1,
    S_INIT_EVAL = 3'd2,
    S_EVAL_SCHED= 3'd3,
    S_NEXT_SCHED= 3'd4,
    S_DONE      = 3'd5
  } state_t;

  state_t state, next_state;

  // Opponent per-minute cheers (0..3)
  reg [2:0] opp_cnt [0:7];

  // Loop/index and control
  reg [3:0] idx_minute;        // can index 0..8
  reg [3:0] cur_start;         // current schedule start minute
  reg [3:0] max_start;         // last valid start index (8 - t)

  // Per-schedule computed tallies
  reg [2:0] cur_sportify_goals;
  reg [2:0] cur_spoilify_goals;

  // Best result tracking
  reg [2:0] best_sportify_goals;
  reg [2:0] best_spoilify_goals;
  // Differences are in range [-4..4], we encode as signed 4-bit
  reg  signed [3:0] best_diff;

  // Combinational: compute max_start based on t
  // Guard for t >= 1 to avoid underflow; if t==0 (illegal), clamp so no valid schedule.
  always @* begin
    if (t == 0 || t > 8)
      max_start = 4'd0; // effectively no valid schedule; treated safely
    else if (8 >= t)
      max_start = 8 - t;
    else
      max_start = 4'd0;
  end

  // Helper task: clear opponent counts
  task automatic clear_opp_cnt;
    integer i;
    begin
      for (i = 0; i < 8; i = i + 1) begin
        opp_cnt[i] = 3'd0;
      end
    end
  endtask

  // Helper task: apply a single interval [a,b) if enabled
  task automatic apply_interval(
    input        enable,
    input  [3:0] a,
    input  [3:0] b
  );
    integer j;
    begin
      if (enable && (a < b) && (b <= 8)) begin
        for (j = a; j < b; j = j + 1) begin
          if (j < 8)
            opp_cnt[j] = (opp_cnt[j] < 3'd7) ? (opp_cnt[j] + 3'd1) : opp_cnt[j];
        end
      end
    end
  endtask

  // Helper task: evaluate goals for a given schedule start (single interval of length t)
  task automatic eval_schedule(
    input  [3:0] start_min,
    output [2:0] s_goals,
    output [2:0] o_goals
  );
    reg [0:7] sportify_cheer;
    integer i;
    reg [2:0] sg;
    reg [2:0] og;
    reg [2:0] s_min;
    reg [2:0] o_min;

    begin
      // Build Sportify cheer mask
      for (i = 0; i < 8; i = i + 1) begin
        if ((i >= start_min) && (i < start_min + t) && (i < 8))
          sportify_cheer[i] = 1'b1;
        else
          sportify_cheer[i] = 1'b0;
      end

      sg = 3'd0;
      og = 3'd0;

      // Fixed 2-minute windows per half:
      // H1: (0,1), (2,3)
      // H2: (4,5), (6,7)
      // For each pair, if both minutes strictly favor same team, that team +1 goal.

      // Pair (0,1)
      if (1 < 8) begin
        s_min = sportify_cheer[0] + sportify_cheer[1];
        o_min = opp_cnt[0] + opp_cnt[1];
        if ((sportify_cheer[0] > opp_cnt[0]) && (sportify_cheer[1] > opp_cnt[1]))
          sg = sg + 3'd1;
        else if ((sportify_cheer[0] < opp_cnt[0]) && (sportify_cheer[1] < opp_cnt[1]))
          og = og + 3'd1;
      end

      // Pair (2,3)
      if (3 < 8) begin
        if ((sportify_cheer[2] > opp_cnt[2]) && (sportify_cheer[3] > opp_cnt[3]))
          sg = sg + 3'd1;
        else if ((sportify_cheer[2] < opp_cnt[2]) && (sportify_cheer[3] < opp_cnt[3]))
          og = og + 3'd1;
      end

      // Pair (4,5)
      if (5 < 8) begin
        if ((sportify_cheer[4] > opp_cnt[4]) && (sportify_cheer[5] > opp_cnt[5]))
          sg = sg + 3'd1;
        else if ((sportify_cheer[4] < opp_cnt[4]) && (sportify_cheer[5] < opp_cnt[5]))
          og = og + 3'd1;
      end

      // Pair (6,7)
      if (7 < 8) begin
        if ((sportify_cheer[6] > opp_cnt[6]) && (sportify_cheer[7] > opp_cnt[7]))
          sg = sg + 3'd1;
        else if ((sportify_cheer[6] < opp_cnt[6]) && (sportify_cheer[7] < opp_cnt[7]))
          og = og + 3'd1;
      end

      s_goals = sg;
      o_goals = og;
    end
  endtask

  // Sequential state, outputs, and main control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state               <= S_IDLE;
      done                <= 1'b0;
      sportify_goals      <= 3'd0;
      spoilify_goals      <= 3'd0;
      best_sportify_goals <= 3'd0;
      best_spoilify_goals <= 3'd0;
      best_diff           <= -4'sd8;
      cur_start           <= 4'd0;
      idx_minute          <= 4'd0;
      clear_opp_cnt();
    end else begin
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Initialize opponent counts and proceed
            clear_opp_cnt();
            state <= S_SETUP_OPP;
          end
        end

        S_SETUP_OPP: begin
          // Build opponent cheer counts based on m
          clear_opp_cnt();
          apply_interval((m > 0), interval_0_a, interval_0_b);
          apply_interval((m > 1), interval_1_a, interval_1_b);
          apply_interval((m > 2), interval_2_a, interval_2_b);

          // Prepare best trackers
          best_sportify_goals <= 3'd0;
          best_spoilify_goals <= 3'd0;
          best_diff           <= -4'sd8; // very small

          // Initialize schedule enumeration
          cur_start  <= 4'd0;
          state      <= S_INIT_EVAL;
        end

        S_INIT_EVAL: begin
          // If t invalid or no valid start positions, treat as zero-schedule baseline
          if ((t == 0) || (t > 8)) begin
            // No valid schedules: goals remain zero
            sportify_goals <= 3'd0;
            spoilify_goals <= 3'd0;
            done           <= 1'b1;
            state          <= S_DONE;
          end else begin
            state <= S_EVAL_SCHED;
          end
        end

        S_EVAL_SCHED: begin
          // Evaluate current schedule (single-cycle task, combinational inside)
          eval_schedule(cur_start, cur_sportify_goals, cur_spoilify_goals);

          // Compute diff and compare to best
          // Cast to signed for difference
          begin : cmp_block
            reg signed [3:0] cur_diff;
            cur_diff = $signed({1'b0, cur_sportify_goals}) - $signed({1'b0, cur_spoilify_goals});

            if ((cur_diff > best_diff) ||
                ((cur_diff == best_diff) && (cur_sportify_goals > best_sportify_goals))) begin
              best_diff           <= cur_diff;
              best_sportify_goals <= cur_sportify_goals;
              best_spoilify_goals <= cur_spoilify_goals;
            end
          end

          state <= S_NEXT_SCHED;
        end

        S_NEXT_SCHED: begin
          if (cur_start >= max_start) begin
            // Finished all schedules, drive outputs
            sportify_goals <= best_sportify_goals;
            spoilify_goals <= best_spoilify_goals;
            done           <= 1'b1;
            state          <= S_DONE;
          end else begin
            // Next schedule
            cur_start <= cur_start + 4'd1;
            state     <= S_EVAL_SCHED;
          end
        end

        S_DONE: begin
          // Hold results until next start or reset
          if (!start) begin
            // Wait for start to deassert before allowing a new run
            // Remain in DONE until new start
          end else begin
            // New computation requested
            done  <= 1'b0;
            clear_opp_cnt();
            state <= S_SETUP_OPP;
          end
        end

        default: begin
          state <= S_IDLE;
        end
      endcase
    end
  end

endmodule