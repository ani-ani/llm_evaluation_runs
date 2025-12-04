module critical_path_optimizer(
  input clk,
  input rst_n,
  input start,
  input [1:0] node_count,
  input [7:0] time_vals [0:3],
  input [3:0] deps [0:3],
  output reg [7:0] min_time,
  output reg done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE              = 2'b00,
    CALCULATE_BASELINE= 2'b01,
    TRY_ELIMINATE     = 2'b10,
    DONE              = 2'b11
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [7:0] base_time;
  reg [7:0] best_time;
  reg [1:0] elim_idx;          // which node index is being eliminated
  reg [1:0] elim_idx_next;
  reg [3:0] step_cnt;          // up to 10 cycles per phase
  reg [3:0] step_cnt_next;

  // Latched inputs (for stability during computation)
  reg [1:0] node_cnt_r;
  reg [7:0] time_vals_r [0:3];
  reg [3:0] deps_r      [0:3];

  // Combinational outputs of topological/DP computation
  reg [7:0] crit_time_baseline;
  reg [7:0] crit_time_elim;

  //========================
  // Critical path compute
  //========================
  // Common: only nodes [0:node_cnt_r-1] are valid.

  // Baseline critical path (no elimination)
  // Fixed-sequence topological DP for up to 4 nodes using dependency masks.
  // dp[i] = time[i] + max(dp[j] for all j where deps[i][j] == 1), else time[i].
  // Critical path = max(dp[i]).
  task automatic compute_crit_time_baseline(
    input  [1:0] n,
    input  [7:0] t [0:3],
    input  [3:0] d [0:3],
    output [7:0] crit
  );
    reg [7:0] dp0, dp1, dp2, dp3;
    reg [7:0] max_prev;
    reg [7:0] res;

    // Node 0
    if (n > 0) begin
      // no valid predecessors with index <0
      dp0 = t[0];
    end else begin
      dp0 = 8'd0;
    end

    // Node 1
    if (n > 1) begin
      max_prev = 8'd0;
      if (d[1][0]) max_prev = dp0;
      dp1 = t[1] + max_prev;
    end else begin
      dp1 = 8'd0;
    end

    // Node 2
    if (n > 2) begin
      max_prev = 8'd0;
      if (d[2][0] && dp0 > max_prev) max_prev = dp0;
      if (d[2][1] && dp1 > max_prev) max_prev = dp1;
      dp2 = t[2] + max_prev;
    end else begin
      dp2 = 8'd0;
    end

    // Node 3
    if (n > 3) begin
      max_prev = 8'd0;
      if (d[3][0] && dp0 > max_prev) max_prev = dp0;
      if (d[3][1] && dp1 > max_prev) max_prev = dp1;
      if (d[3][2] && dp2 > max_prev) max_prev = dp2;
      dp3 = t[3] + max_prev;
    end else begin
      dp3 = 8'd0;
    end

    // Critical path = max over valid nodes
    res = 8'd0;
    if (n > 0 && dp0 > res) res = dp0;
    if (n > 1 && dp1 > res) res = dp1;
    if (n > 2 && dp2 > res) res = dp2;
    if (n > 3 && dp3 > res) res = dp3;

    crit = res;
  endtask

  // Critical path with one node eliminated (its time set to 0)
  task automatic compute_crit_time_elim(
    input  [1:0] n,
    input  [7:0] t [0:3],
    input  [3:0] d [0:3],
    input  [1:0] elim,
    output [7:0] crit
  );
    reg [7:0] tt [0:3];
    reg [7:0] dp0, dp1, dp2, dp3;
    reg [7:0] max_prev;
    reg [7:0] res;

    // Apply elimination: set that node's time to 0
    tt[0] = (elim == 2'd0) ? 8'd0 : t[0];
    tt[1] = (elim == 2'd1) ? 8'd0 : t[1];
    tt[2] = (elim == 2'd2) ? 8'd0 : t[2];
    tt[3] = (elim == 2'd3) ? 8'd0 : t[3];

    // Node 0
    if (n > 0) begin
      dp0 = tt[0];
    end else begin
      dp0 = 8'd0;
    end

    // Node 1
    if (n > 1) begin
      max_prev = 8'd0;
      if (d[1][0]) max_prev = dp0;
      dp1 = tt[1] + max_prev;
    end else begin
      dp1 = 8'd0;
    end

    // Node 2
    if (n > 2) begin
      max_prev = 8'd0;
      if (d[2][0] && dp0 > max_prev) max_prev = dp0;
      if (d[2][1] && dp1 > max_prev) max_prev = dp1;
      dp2 = tt[2] + max_prev;
    end else begin
      dp2 = 8'd0;
    end

    // Node 3
    if (n > 3) begin
      max_prev = 8'd0;
      if (d[3][0] && dp0 > max_prev) max_prev = dp0;
      if (d[3][1] && dp1 > max_prev) max_prev = dp1;
      if (d[3][2] && dp2 > max_prev) max_prev = dp2;
      dp3 = tt[3] + max_prev;
    end else begin
      dp3 = 8'd0;
    end

    // Critical path = max over valid nodes
    res = 8'd0;
    if (n > 0 && dp0 > res) res = dp0;
    if (n > 1 && dp1 > res) res = dp1;
    if (n > 2 && dp2 > res) res = dp2;
    if (n > 3 && dp3 > res) res = dp3;

    crit = res;
  endtask

  //========================
  // Combinational: compute critical times from latched data
  //========================
  always @* begin
    compute_crit_time_baseline(node_cnt_r, time_vals_r, deps_r, crit_time_baseline);
    compute_crit_time_elim(node_cnt_r, time_vals_r, deps_r, elim_idx, crit_time_elim);
  end

  //========================
  // Next-state logic
  //========================
  always @* begin
    next_state     = state;
    step_cnt_next  = step_cnt;
    elim_idx_next  = elim_idx;

    case (state)
      IDLE: begin
        if (start) begin
          next_state    = CALCULATE_BASELINE;
          step_cnt_next = 4'd0;
          elim_idx_next = 2'd0;
        end
      end

      CALCULATE_BASELINE: begin
        // Wait fixed up to 10 cycles (can be reduced, but bounded as required)
        if (step_cnt == 4'd9) begin
          next_state    = TRY_ELIMINATE;
          step_cnt_next = 4'd0;
          elim_idx_next = 2'd0;
        end else begin
          step_cnt_next = step_cnt + 4'd1;
        end
      end

      TRY_ELIMINATE: begin
        // Each elimination candidate gets up to 10 cycles window
        if (step_cnt == 4'd9) begin
          step_cnt_next = 4'd0;
          if (elim_idx == (node_cnt_r - 1)) begin
            next_state = DONE;
          end else begin
            elim_idx_next = elim_idx + 2'd1;
          end
        end else begin
          step_cnt_next = step_cnt + 4'd1;
        end
      end

      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  //========================
  // Sequential logic
  //========================
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      step_cnt    <= 4'd0;
      elim_idx    <= 2'd0;
      node_cnt_r  <= 2'd0;
      for (i = 0; i < 4; i = i + 1) begin
        time_vals_r[i] <= 8'd0;
        deps_r[i]      <= 4'd0;
      end
      base_time  <= 8'd0;
      best_time  <= 8'hFF;
      min_time   <= 8'd0;
      done       <= 1'b0;
    end else begin
      state    <= next_state;
      step_cnt <= step_cnt_next;
      elim_idx <= elim_idx_next;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Latch inputs at start
            node_cnt_r <= (node_count < 2'd2) ? 2'd2 : node_count;
            for (i = 0; i < 4; i = i + 1) begin
              time_vals_r[i] <= time_vals[i];
              deps_r[i]      <= deps[i];
            end
            best_time <= 8'hFF; // initialize high
          end
        end

        CALCULATE_BASELINE: begin
          // At the final cycle of this state, capture baseline
          if (step_cnt == 4'd9) begin
            base_time <= crit_time_baseline;
            // Initialize best_time with a large value; actual best computed in TRY_ELIMINATE
            best_time <= 8'hFF;
          end
        end

        TRY_ELIMINATE: begin
          // At the end of each 10-cycle window, evaluate the current elimination candidate
          if (step_cnt == 4'd9) begin
            if (crit_time_elim < best_time)
              best_time <= crit_time_elim;
          end
        end

        DONE: begin
          done <= 1'b1;
          // Select minimal critical path when one step can be eliminated
          // If best_time never updated (still 0xFF), fall back to base_time
          if (best_time == 8'hFF)
            min_time <= base_time;
          else
            min_time <= best_time;
        end

        default: begin
          // no-op
        end
      endcase
    end
  end

endmodule
