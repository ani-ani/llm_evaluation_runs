module torpedo_avoidance(
  input clk,
  input rst_n,
  input start,
  input [3:0] n_seconds, // Total steps (2-8)
  input [2:0] m_ships,   // 0-4 ships
  input signed [4:0] ship_x1 [0:3], // 4 ships max (-8 to +8)
  input signed [4:0] ship_x2 [0:3],
  input [3:0] ship_y [0:3],
  output reg [1:0] path [0:7], // 8 steps max (2'b00:-, 2'b01:0, 2'b10:+)
  output reg done,
  output reg possible
);

  // Assumptions / interpretation:
  // - Torpedo starts at x=0 at time step 0 (y=0).
  // - At each step k (1..n_seconds) torpedo may change x by -1, 0, or +1.
  // - Ships define forbidden intervals [ship_x1, ship_x2] at their ship_y.
  // - We treat all coordinates as within [-8,+8]; states outside are never generated.
  // - We compute the earliest arrival at each reachable (step, x) using a 3-bit
  //   signed "predecessor move" grid that allows unique path reconstruction.
  // - Latency: result asserted exactly (n_seconds + 1) cycles after 'start'.

  // FSM for control
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    COMP  = 2'b01,
    TRACE = 2'b10
  } state_t;

  state_t state, next_state;

  // Internal counters / regs
  reg [3:0] step_cnt;           // 0..8
  reg [3:0] target_steps;       // latched n_seconds
  reg [2:0] ships_cnt;          // latched m_ships

  // Ship info latched at start
  reg signed [4:0] ship_x1_r [0:3];
  reg signed [4:0] ship_x2_r [0:3];
  reg [3:0]        ship_y_r  [0:3];

  // Reachability: for each step (0..8) and x index (0..16 => -8..+8)
  // we store whether cell is reachable and its predecessor move.
  // x index encoding: idx = x + 8
  reg        reachable [0:8][0:16];
  reg signed [1:0] prev_move [0:8][0:16]; // -1,0,+1: move applied at this step from previous x

  // Track if any position reachable at final step
  reg any_reach_final;

  // Selected final x index for traceback
  reg [4:0] tb_x_idx;  // 0..16
  reg [3:0] tb_step;   // countdown during TRACE

  integer i, xi;

  // Function: check if (step, x) collides with any ship
  function automatic collision_at;
    input [3:0] step;
    input signed [4:0] x;
    integer si;
    begin
      collision_at = 1'b0;
      for (si = 0; si < 4; si = si + 1) begin
        if (si < ships_cnt) begin
          if (ship_y_r[si] == step) begin
            if ((x >= ship_x1_r[si]) && (x <= ship_x2_r[si])) begin
              collision_at = 1'b1;
            end
          end
        end
      end
    end
  endfunction

  // Synchronous control & datapath
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      done          <= 1'b0;
      possible      <= 1'b0;
      step_cnt      <= 4'd0;
      target_steps  <= 4'd0;
      ships_cnt     <= 3'd0;
      tb_x_idx      <= 5'd0;
      tb_step       <= 4'd0;
      any_reach_final <= 1'b0;
      // Clear arrays
      for (i = 0; i <= 8; i = i + 1) begin
        for (xi = 0; xi <= 16; xi = xi + 1) begin
          reachable[i][xi] <= 1'b0;
          prev_move[i][xi] <= 2'sd0;
        end
      end
      for (i = 0; i < 8; i = i + 1) begin
        path[i] <= 2'b00;
      end
      for (i = 0; i < 4; i = i + 1) begin
        ship_x1_r[i] <= 5'sd0;
        ship_x2_r[i] <= 5'sd0;
        ship_y_r[i]  <= 4'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done     <= 1'b0;
          possible <= 1'b0;
          if (start) begin
            // Latch configuration
            target_steps <= n_seconds;
            ships_cnt    <= m_ships;
            for (i = 0; i < 4; i = i + 1) begin
              ship_x1_r[i] <= ship_x1[i];
              ship_x2_r[i] <= ship_x2[i];
              ship_y_r[i]  <= ship_y[i];
            end
            // Initialize reachability for step 0
            for (i = 0; i <= 8; i = i + 1) begin
              for (xi = 0; xi <= 16; xi = xi + 1) begin
                reachable[i][xi] <= 1'b0;
                prev_move[i][xi] <= 2'sd0;
              end
            end
            for (i = 0; i < 8; i = i + 1) begin
              path[i] <= 2'b00;
            end
            // Start at x=0 -> idx=8
            reachable[0][8] <= 1'b1;
            step_cnt        <= 4'd0;
            any_reach_final <= 1'b0;
          end
        end

        COMP: begin
          // Compute next step = step_cnt + 1 from current step_cnt
          // Use previous layer reachable[step_cnt][:]
          // First, clear new layer
          for (xi = 0; xi <= 16; xi = xi + 1) begin
            reachable[step_cnt + 1][xi] <= 1'b0;
            prev_move[step_cnt + 1][xi] <= 2'sd0;
          end

          // Generate candidates
          for (xi = 0; xi <= 16; xi = xi + 1) begin
            if (reachable[step_cnt][xi]) begin
              // current x = xi - 8
              // Try moves -1,0,+1
              // move -1
              if (xi > 0) begin
                if (!collision_at(step_cnt + 1, $signed(xi - 1 - 8))) begin
                  if (!reachable[step_cnt + 1][xi - 1]) begin
                    reachable[step_cnt + 1][xi - 1] <= 1'b1;
                    prev_move[step_cnt + 1][xi - 1] <= -2'sd1;
                  end
                end
              end
              // move 0
              if (!collision_at(step_cnt + 1, $signed(xi - 8))) begin
                if (!reachable[step_cnt + 1][xi]) begin
                  reachable[step_cnt + 1][xi] <= 1'b1;
                  prev_move[step_cnt + 1][xi] <= 2'sd0;
                end
              end
              // move +1
              if (xi < 16) begin
                if (!collision_at(step_cnt + 1, $signed(xi + 1 - 8))) begin
                  if (!reachable[step_cnt + 1][xi + 1]) begin
                    reachable[step_cnt + 1][xi + 1] <= 1'b1;
                    prev_move[step_cnt + 1][xi + 1] <= 2'sd1;
                  end
                end
              end
            end
          end

          step_cnt <= step_cnt + 1'b1;

          // When we've just computed layer target_steps, prepare summary
          if (step_cnt + 1 == target_steps) begin
            any_reach_final <= 1'b0;
            tb_x_idx        <= 5'd0;
            for (xi = 0; xi <= 16; xi = xi + 1) begin
              if (reachable[target_steps][xi] && !any_reach_final) begin
                any_reach_final <= 1'b1;
                tb_x_idx        <= xi[4:0];
              end
            end
            // tb_step loaded in TRACE state
          end
        end

        TRACE: begin
          // Traceback over target_steps steps (one per cycle)
          if (!possible) begin
            // No possible path, nothing to trace
          end else begin
            // For tb_step in [target_steps..1]
            // At entry to TRACE, tb_step initialized to target_steps
            if (tb_step != 0) begin
              // Read move used to reach (tb_step, tb_x_idx)
              case (prev_move[tb_step][tb_x_idx])
                -2'sd1: path[tb_step - 1] <= 2'b00; // move -1 => code '-'
                2'sd0:  path[tb_step - 1] <= 2'b01; // move  0 => code '0'
                2'sd1:  path[tb_step - 1] <= 2'b10; // move +1 => code '+'
                default: path[tb_step - 1] <= 2'b00;
              endcase

              // Update x index for previous step
              if (prev_move[tb_step][tb_x_idx] == -2'sd1) begin
                tb_x_idx <= tb_x_idx + 1'b1; // x_prev = x_curr - (-1) = x_curr +1
              end else if (prev_move[tb_step][tb_x_idx] == 2'sd0) begin
                tb_x_idx <= tb_x_idx;       // unchanged
              end else if (prev_move[tb_step][tb_x_idx] == 2'sd1) begin
                tb_x_idx <= tb_x_idx - 1'b1; // x_prev = x_curr - (+1)
              end else begin
                tb_x_idx <= tb_x_idx;       // safety
              end

              tb_step <= tb_step - 1'b1;
            end
          end
        end

        default: ;
      endcase

      // done/possible strobes managed via next_state logic fall-through
    end
  end

  // Next-state logic & output control (combinational)
  always @(*) begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = COMP;
        end
      end

      COMP: begin
        if (step_cnt == target_steps) begin
          // We have already computed up to target_steps
          if (any_reach_final) begin
            next_state = TRACE;
          end else begin
            next_state = TRACE; // still go TRACE to emit done with possible=0
          end
        end
      end

      TRACE: begin
        // Control done/possible based on traceback progress
        // Sequential block updates tb_step; here we infer termination
        // When tb_step reaches 0 we are finished (or no path case)
        if (tb_step == 0) begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

  // Manage done and possible signals based on state transitions
  // Ensure done is high exactly at cycle (target_steps + 1) after start:
  // - COMP runs for target_steps cycles.
  // - TRACE runs 1 cycle where tb_step initialized and done asserted.
  // We assert done when entering TRACE and tb_step == target_steps.

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done     <= 1'b0;
      possible <= 1'b0;
      tb_step  <= 4'd0;
    end else begin
      if (state == COMP && next_state == TRACE) begin
        // Just finished all computations, enter TRACE
        tb_step  <= target_steps;
        possible <= any_reach_final;
        done     <= 1'b1; // done exactly at (n_seconds + 1)th cycle
      end else if (state == TRACE) begin
        // Keep done asserted only for the first TRACE cycle
        done <= 1'b0;
      end else if (state == IDLE) begin
        done <= 1'b0;
      end
    end
  end

endmodule
