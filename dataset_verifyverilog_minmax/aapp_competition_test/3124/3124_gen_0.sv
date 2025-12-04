module ivana_game (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,              // 1..8
  input [9:0] nums [0:7],      // 8 numbers, 10-bit each
  output reg [3:0] win_count,  // 0..8
  output reg done
);

  // Internal constants
  localparam W = 8;            // width (max 8 positions)
  localparam MAXQ = 256;       // per-column BFS frontier queue depth (2^W max)
  localparam MAXD = 8;         // maximum game depth (n)
  localparam S_IDLE = 2'b00, S_RUN = 2'b01, S_DONE = 2'b10;

  // Precompute odd/even per mask (2^8 = 256 entries)
  logic [7:0] odd_cnt [0:255];
  logic [7:0] even_cnt [0:255];
  initial begin
    for (int m = 0; m < 256; m++) begin
      automatic int oc = 0;
      for (int b = 0; b < 8; b++) begin
        if (m[b]) begin
          // nums[b][0] is the least significant bit of the 10-bit number
          if (nums[b][0]) oc++;
        end
      end
      odd_cnt[m]  = oc[7:0];
      even_cnt[m] = (8 - oc);
    end
  end

  // Simple function to evaluate a terminal state (current player to move)
  function automatic bit winner_ivana(bit [7:0] mask, bit turn_ivana);
    automatic int oc = odd_cnt[mask];
    if (oc > (8 - oc)) return 1'b1;          // Ivana has more odd numbers
    else if (oc < (8 - oc)) return 1'b0;     // Opponent has more
    else return ~turn_ivana;                 // draw: current player loses (prefers pass)
  endfunction

  // BFS per-start state
  typedef struct packed {
    bit [7:0] mask;
    bit [2:0] level;   // 0..8 (max depth = n <= 8)
  } bfs_state_t;

  // Packed BFS queues and pointers (8 columns in parallel)
  logic [7:0]   q_mask [0:7][0:MAXQ-1];
  logic [2:0]   q_level [0:7][0:MAXQ-1];
  logic [7:0]   head [0:7];
  logic [7:0]   tail [0:7];
  logic [7:0]   head_next [0:7];
  logic [7:0]   tail_next [0:7];

  logic [7:0]   last_mask_cur [0:7];  // last mask processed in current level
  logic         last_is_cur [0:7];    // 1 if last popped mask in current level (for this column)
  logic         enqueue_next [0:7];   // whether we enqueued any child into next level

  // BFS state/results per column
  logic [1:0]   fsm_state;
  logic [7:0]   max_n;                // n (zero-padded to 8-bit)
  logic [2:0]   cycle_cnt;            // elapsed cycles after start (0..15)
  logic [7:0]   result [0:7];         // 2=undetermined, 1=Ivana win, 0=not win
  logic [7:0]   col_done [0:7];       // per-column completion flag
  logic [7:0]   col_active;           // columns active (first n)

  // Initialize
  initial begin
    fsm_state = S_IDLE;
    done = 1'b0;
    win_count = 4'b0;
    cycle_cnt = 3'b0;
    for (int c = 0; c < 8; c++) begin
      head[c] = 8'b0; tail[c] = 8'b0;
      head_next[c] = 8'b0; tail_next[c] = 8'b0;
      last_is_cur[c] = 1'b0;
      enqueue_next[c] = 1'b0;
      result[c] = 2'b10; // undetermined
      col_done[c] = 1'b0;
    end
  end

  // Reset and start logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fsm_state <= S_IDLE;
      done <= 1'b0;
      win_count <= 4'b0;
      cycle_cnt <= 3'b0;
      max_n <= 8'b0;
      col_active <= 8'b0;
      for (int c = 0; c < 8; c++) begin
        head[c] <= 8'b0; tail[c] <= 8'b0;
        head_next[c] <= 8'b0; tail_next[c] <= 8'b0;
        last_is_cur[c] <= 1'b0;
        enqueue_next[c] <= 1'b0;
        result[c] <= 2'b10;
        col_done[c] <= 1'b0;
      end
    end else if (start && fsm_state == S_IDLE) begin
      // Initialize BFS for all 8 columns, but we will only use first n columns
      fsm_state <= S_RUN;
      done <= 1'b0;
      win_count <= 4'b0;
      cycle_cnt <= 3'b0;
      max_n <= {5'b0, n};           // zero-extend to 8 bits
      col_active <= (n == 1) ? 8'b00000001 :
                    (n == 2) ? 8'b00000011 :
                    (n == 3) ? 8'b00000111 :
                    (n == 4) ? 8'b00001111 :
                    (n == 5) ? 8'b00011111 :
                    (n == 6) ? 8'b00111111 :
                    (n == 7) ? 8'b01111111 : 8'b11111111;

      for (int c = 0; c < 8; c++) begin
        head[c] <= 8'b0; tail[c] <= 8'b0;
        head_next[c] <= 8'b0; tail_next[c] <= 8'b0;
        last_is_cur[c] <= 1'b0;
        enqueue_next[c] <= 1'b0;
        result[c] <= 2'b10;     // undetermined
        col_done[c] <= 1'b0;
        // Push initial state for each column: mask = (n active bits starting at c), level = 0
        if (c < n) begin
          // initial circular mask: active indices c, c+1, ..., c+n-1 (mod 8)
          automatic bit [7:0] m0 = 8'b0;
          for (int k = 0; k < 8; k++) begin
            int idx;
            idx = (c + k) % 8;
            if (k < n) m0[idx] = 1'b1;
            else m0[idx] = 1'b0;
          end
          q_mask[c][0]  <= m0;
          q_level[c][0] <= 3'b0;
          head[c] <= 8'b0;
          tail[c] <= 8'b1; // one element enqueued
        end else begin
          head[c] <= 8'b0;
          tail[c] <= 8'b0;
        end
      end
    end else if (fsm_state == S_RUN) begin
      cycle_cnt <= cycle_cnt + 3'b1;

      // Default: keep state, updated below
      for (int c = 0; c < 8; c++) begin
        head_next[c] <= head[c];
        tail_next[c] <= tail[c];
        enqueue_next[c] <= 1'b0;
        last_is_cur[c] <= 1'b0;
        // clear last_mask_cur default (will be overwritten as used)
        last_mask_cur[c] <= 8'b0;
      end

      // Process one state per column per cycle, if available
      for (int c = 0; c < 8; c++) begin
        // Skip inactive columns
        if (!col_active[c]) continue;
        // If already done for this column, skip
        if (col_done[c]) continue;

        if (head[c] == tail[c]) begin
          // Empty queue and not done -> should not happen, but mark as not win (draw)
          result[c] <= 1'b0;
          col_done[c] <= 1'b1;
          continue;
        end

        // Peek current state
        automatic bit [7:0] cur_mask;
        automatic bit [2:0] cur_level;
        automatic int cur_head;
        cur_head = head[c];
        cur_mask = q_mask[c][cur_head];
        cur_level = q_level[c][cur_head];

        // Determine if this is the last node in current level
        // If next state in queue has different level (or queue empty), this is last in level
        automatic int next_head_int;
        next_head_int = (cur_head + 1) % MAXQ;
        automatic bit is_last_in_level;
        if (next_head_int == tail[c]) is_last_in_level = 1'b1;
        else is_last_in_level = (q_level[c][next_head_int] != cur_level);

        // Pop current state
        head_next[c] = (cur_head + 1) % MAXQ;
        last_is_cur[c] = is_last_in_level;
        last_mask_cur[c] = cur_mask;

        // Generate children (next level = cur_level + 1, bounded by max_n)
        if (cur_level < max_n) begin
          // Determine player to move for this level (Ivana moves at odd levels if Ivana starts at level 0)
          // We only need this to evaluate terminal children
          automatic bit turn_ivana_cur;
          turn_ivana_cur = cur_level[0]; // 1 => Ivana's turn, 0 => Opponent's turn

          // Scan bits of cur_mask in circular order starting from c
          automatic int scanned = 0;
          automatic int b = 0;
          // iterate up to W bits but break when no more available
          for (int offset = 0; offset < 8; offset++) begin
            b = (c + offset) % 8;
            if (cur_mask[b]) begin
              automatic bit [7:0] child_mask;
              child_mask = cur_mask & (~(1 << b));
              automatic int oc_child;
              oc_child = odd_cnt[child_mask];
              // terminal if no bits left (all selected)
              if (child_mask == 8'b0) begin
                // Evaluate terminal: who wins from this state (next player to move)
                automatic bit next_is_ivana;
                next_is_ivana = ~turn_ivana_cur; // after current move
                automatic bit iw;
                iw = winner_ivana(child_mask, next_is_ivana);
                // If current player to move has a terminal move that secures a win, this path is winning.
                if (iw) begin
                  result[c] <= 1'b1; // Ivana can force a win from this state
                  col_done[c] <= 1'b1;
                  // Do not enqueue further
                end else begin
                  // Not a forced win via terminal move; continue BFS by enqueuing this child (if not already full)
                  if (!enqueue_next[c]) begin
                    automatic int ntail;
                    ntail = tail_next[c];
                    // Only enqueue if there is room
                    if ((ntail + 1) % MAXQ != head_next[c]) begin
                      q_mask[c][ntail]  <= child_mask;
                      q_level[c][ntail] <= cur_level + 1;
                      tail_next[c] = (ntail + 1) % MAXQ;
                      enqueue_next[c] <= 1'b1;
                    end
                  end else begin
                    // enqueue_next already used this cycle; still need to keep tail_next advancing if possible
                    if ((tail_next[c] + 1) % MAXQ != head_next[c]) begin
                      tail_next[c] = (tail_next[c] + 1) % MAXQ;
                    end
                  end
                end
              end else begin
                // Non-terminal child: enqueue to next level (if room)
                if (!enqueue_next[c]) begin
                  automatic int ntail2;
                  ntail2 = tail_next[c];
                  if ((ntail2 + 1) % MAXQ != head_next[c]) begin
                    q_mask[c][ntail2]  <= child_mask;
                    q_level[c][ntail2] <= cur_level + 1;
                    tail_next[c] = (ntail2 + 1) % MAXQ;
                    enqueue_next[c] <= 1'b1;
                  end
                end else begin
                  if ((tail_next[c] + 1) % MAXQ != head_next[c]) begin
                    tail_next[c] = (tail_next[c] + 1) % MAXQ;
                  end
                end
              end
            end
            // Stop when scanned all bits of current mask
            scanned++;
            if (scanned >= 8) break;
          end // for offsets
        end else begin
          // Reached max depth without conclusion -> treat as not win (draw)
          if (is_last_in_level) begin
            result[c] <= 1'b0;
            col_done[c] <= 1'b1;
          end
        end

        // If this was the last node of the current level and we did not already set a forced win,
        // and the next level queue is empty (i.e., no children enqueued), then it's a draw -> not win.
        if (is_last_in_level && !col_done[c] && !enqueue_next[c]) begin
          result[c] <= 1'b0;
          col_done[c] <= 1'b1;
        end

        // Swap frontiers: next level becomes current, if any enqueued this cycle
        if (is_last_in_level && enqueue_next[c]) begin
          // Move to next level: replace head/tail with next pointers
          head_next[c] <= head_next[c];
          tail_next[c] <= tail_next[c];
        end else begin
          // Keep current pointers (already updated head_next above for pop)
        end

      end // for each column

      // Commit pointer updates
      for (int c = 0; c < 8; c++) begin
        head[c] <= head_next[c];
        tail[c] <= tail_next[c];
      end

      // Check completion of all active columns or after 16 cycles
      if (&col_active === 1'b1) begin
        if ((col_done[0] && col_done[1] && col_done[2] && col_done[3] &&
             col_done[4] && col_done[5] && col_done[6] && col_done[7]) ||
            (cycle_cnt == 4'b1111)) begin
          fsm_state <= S_DONE;
          done <= 1'b1;
          // Count wins among first n starts
          automatic int wc;
          wc = 0;
          for (int c = 0; c < 8; c++) begin
            if (c < n) begin
              if (result[c] == 1'b1) wc++;
            end
          end
          win_count <= wc[3:0];
        end
      end else begin
        // If not all columns active (n<8), only consider first n
        automatic bit all_done;
        all_done = 1'b1;
        for (int c = 0; c < 8; c++) begin
          if (col_active[c] && !col_done[c]) all_done = 1'b0;
        end
        if (all_done || (cycle_cnt == 4'b1111)) begin
          fsm_state <= S_DONE;
          done <= 1'b1;
          automatic int wc2;
          wc2 = 0;
          for (int c = 0; c < 8; c++) begin
            if (col_active[c] && (result[c] == 1'b1)) wc2++;
          end
          win_count <= wc2[3:0];
        end
      end
    end else if (fsm_state == S_DONE) begin
      // Hold outputs
      done <= 1'b1;
    end
  end

endmodule
