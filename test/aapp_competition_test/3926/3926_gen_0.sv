module maze_navigator(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start computation
  input [2:0] start_row, // Starting row (0-7)
  input [2:0] start_col, // Starting column (0-7)
  input [2:0] max_left, // Max left moves (0-7)
  input [2:0] max_right, // Max right moves (0-7)
  input [63:0] grid, // Flattened 8x8 maze (1 bit per cell: 0=free, 1=obstacle)
  output reg [5:0] reachable_count, // Number of reachable cells (0-64)
  output reg done // High when computation completes
);

  // State encoding
  localparam IDLE       = 2'd0;
  localparam PROCESSING = 2'd1;
  localparam DONE       = 2'd2;

  reg [1:0] state, state_n;

  // Visited bitmap
  reg [63:0] visited, visited_n;

  // Left/right budget for each cell (3 bits each) => 64 * 3 = 192 bits
  reg [191:0] left_budget, left_budget_n;
  reg [191:0] right_budget, right_budget_n;

  // Queue for BFS: up to 64 entries, each holds {row[2:0], col[2:0]}
  reg [5:0]  q_head, q_head_n;
  reg [5:0]  q_tail, q_tail_n;
  reg        q_empty, q_empty_n;
  reg [5:0]  q_count, q_count_n;
  reg [5:0]  queue [0:63];
  reg [5:0]  queue_n [0:63];

  // Current node being processed
  reg [2:0] cur_row, cur_row_n;
  reg [2:0] cur_col, cur_col_n;

  // Direction step index (0..3): 0=UP,1=DOWN,2=LEFT,3=RIGHT
  reg [1:0] dir_idx, dir_idx_n;

  // Reachable count
  reg [5:0] reachable_count_n;

  // Helper wires
  wire [5:0] cur_idx = {cur_row, cur_col};

  // Functions to access budgets
  function automatic [2:0] get_left_budget(input [191:0] vec, input [5:0] idx);
    get_left_budget = vec[idx*3 +: 3];
  endfunction

  function automatic [2:0] get_right_budget(input [191:0] vec, input [5:0] idx);
    get_right_budget = vec[idx*3 +: 3];
  endfunction

  function automatic [191:0] set_left_budget(
    input [191:0] vec,
    input [5:0] idx,
    input [2:0] val
  );
    reg [191:0] tmp;
    begin
      tmp = vec;
      tmp[idx*3 +: 3] = val;
      set_left_budget = tmp;
    end
  endfunction

  function automatic [191:0] set_right_budget(
    input [191:0] vec,
    input [5:0] idx,
    input [2:0] val
  );
    reg [191:0] tmp;
    begin
      tmp = vec;
      tmp[idx*3 +: 3] = val;
      set_right_budget = tmp;
    end
  endfunction

  // Compute neighbor for the current direction
  function automatic [5:0] compute_next_idx(
    input [2:0] row,
    input [2:0] col,
    input [1:0] dir
  );
    reg [2:0] nr, nc;
    begin
      nr = row;
      nc = col;
      case (dir)
        2'd0: if (row != 3'd0)       nr = row - 3'd1; // UP
        2'd1: if (row != 3'd7)       nr = row + 3'd1; // DOWN
        2'd2: if (col != 3'd0)       nc = col - 3'd1; // LEFT
        2'd3: if (col != 3'd7)       nc = col + 3'd1; // RIGHT
        default: ;
      endcase
      compute_next_idx = {nr, nc};
    end
  endfunction

  // Determine if move is in-bounds for given dir
  function automatic in_bounds(
    input [2:0] row,
    input [2:0] col,
    input [1:0] dir
  );
    begin
      case (dir)
        2'd0: in_bounds = (row != 3'd0);      // UP
        2'd1: in_bounds = (row != 3'd7);      // DOWN
        2'd2: in_bounds = (col != 3'd0);      // LEFT
        2'd3: in_bounds = (col != 3'd7);      // RIGHT
        default: in_bounds = 1'b0;
      endcase
    end
  endfunction

  // Check if grid cell is obstacle (1) at given idx
  function automatic is_obstacle(
    input [63:0] g,
    input [5:0] idx
  );
    begin
      is_obstacle = g[idx];
    end
  endfunction

  // Next-state combinational logic
  integer i;
  always @* begin
    // Default hold
    state_n           = state;
    visited_n         = visited;
    left_budget_n     = left_budget;
    right_budget_n    = right_budget;
    q_head_n          = q_head;
    q_tail_n          = q_tail;
    q_count_n         = q_count;
    q_empty_n         = q_empty;
    cur_row_n         = cur_row;
    cur_col_n         = cur_col;
    dir_idx_n         = dir_idx;
    reachable_count_n = reachable_count;

    // Default queue next = current contents
    for (i = 0; i < 64; i = i + 1) begin
      queue_n[i] = queue[i];
    end

    case (state)
      IDLE: begin
        // Wait for start; clear outputs when a new start is seen
        if (start) begin
          // Clear state
          visited_n         = 64'd0;
          left_budget_n     = {192{1'b0}};
          right_budget_n    = {192{1'b0}};
          q_head_n          = 6'd0;
          q_tail_n          = 6'd0;
          q_count_n         = 6'd0;
          q_empty_n         = 1'b1;
          reachable_count_n = 6'd0;
          dir_idx_n         = 2'd0;

          // Compute start index
          if (!is_obstacle(grid, {start_row, start_col})) begin
            // Mark visited and set budgets for start cell
            visited_n[{start_row, start_col}] = 1'b1;
            left_budget_n  = set_left_budget(left_budget_n, {start_row, start_col}, max_left);
            right_budget_n = set_right_budget(right_budget_n, {start_row, start_col}, max_right);

            // Push start cell into queue
            queue_n[0] = {start_row, start_col};
            q_tail_n   = 6'd1;
            q_count_n  = 6'd1;
            q_empty_n  = 1'b0;

            // Count includes start cell
            reachable_count_n = 6'd1;

            state_n = PROCESSING;
          end
          else begin
            // Start cell is obstacle: immediate done with zero reachable
            reachable_count_n = 6'd0;
            state_n           = DONE;
          end
        end
      end

      PROCESSING: begin
        // If queue empty, we are done
        if (q_count == 0 || q_empty) begin
          state_n  = DONE;
        end else begin
          // If dir_idx == 0, fetch new current cell from queue
          if (dir_idx == 2'd0) begin
            // Pop from queue
            {cur_row_n, cur_col_n} = queue[q_head];
            q_head_n  = q_head + 6'd1;
            q_count_n = q_count - 6'd1;
            if (q_head_n + 6'd0 == q_tail) begin
              q_empty_n = (q_count_n == 0);
            end else begin
              q_empty_n = (q_count_n == 0);
            end
          end

          // Process one direction per cycle (priority: UP,DOWN,LEFT,RIGHT)
          // Use current cur_row/cur_col (or cur_row_n/cur_col_n when dir_idx==0)
          // Select appropriate row/col for this cycle
          // For dir_idx==0 we just loaded cur_*_n, but cur_* still old; rely on *_n
          // so define effective row/col
          reg [2:0] eff_row;
          reg [2:0] eff_col;
          eff_row = (dir_idx == 2'd0) ? cur_row_n : cur_row;
          eff_col = (dir_idx == 2'd0) ? cur_col_n : cur_col;

          if (in_bounds(eff_row, eff_col, dir_idx)) begin
            // Compute neighbor index
            reg [5:0] n_idx;
            reg [2:0] n_row;
            reg [2:0] n_col;
            reg [2:0] cur_l;
            reg [2:0] cur_r;
            reg [2:0] nxt_l;
            reg [2:0] nxt_r;
            n_idx = compute_next_idx(eff_row, eff_col, dir_idx);
            n_row = n_idx[5:3];
            n_col = n_idx[2:0];

            // Get budgets of current cell
            cur_l = get_left_budget(left_budget_n, {eff_row, eff_col});
            cur_r = get_right_budget(right_budget_n, {eff_row, eff_col});

            // Check obstacle and visited
            if (!is_obstacle(grid, n_idx) && !visited_n[n_idx]) begin
              // Compute budgets for neighbor depending on direction
              nxt_l = cur_l;
              nxt_r = cur_r;

              case (dir_idx)
                2'd0: begin
                  // UP: budgets unchanged
                  nxt_l = cur_l;
                  nxt_r = cur_r;
                end
                2'd1: begin
                  // DOWN: budgets unchanged
                  nxt_l = cur_l;
                  nxt_r = cur_r;
                end
                2'd2: begin
                  // LEFT: requires available left budget
                  if (cur_l != 3'd0) begin
                    nxt_l = cur_l - 3'd1;
                    nxt_r = cur_r;
                  end else begin
                    // invalid move; mark as no-add
                    nxt_l = 3'd7; // dummy
                    nxt_r = 3'd0;
                  end
                end
                2'd3: begin
                  // RIGHT: requires available right budget
                  if (cur_r != 3'd0) begin
                    nxt_r = cur_r - 3'd1;
                    nxt_l = cur_l;
                  end else begin
                    // invalid move; mark as no-add
                    nxt_l = 3'd7; // dummy
                    nxt_r = 3'd0;
                  end
                end
              endcase

              // Decide if neighbor is enqueued (valid budget for LR or any for UD)
              if ((dir_idx == 2'd0) || (dir_idx == 2'd1) ||
                  ((dir_idx == 2'd2) && (cur_l != 3'd0)) ||
                  ((dir_idx == 2'd3) && (cur_r != 3'd0))) begin
                // Mark visited
                visited_n[n_idx] = 1'b1;
                // Set neighbor budgets
                left_budget_n  = set_left_budget(left_budget_n,  n_idx, nxt_l);
                right_budget_n = set_right_budget(right_budget_n, n_idx, nxt_r);

                // Enqueue neighbor (if space; queue holds 64 max)
                queue_n[q_tail] = n_idx;
                q_tail_n        = q_tail + 6'd1;
                q_count_n       = q_count_n + 6'd1;
                q_empty_n       = 1'b0;

                // Increment reachable count
                reachable_count_n = reachable_count_n + 6'd1;
              end
            end
          end

          // Advance direction index (0->1->2->3->0)
          if (dir_idx == 2'd3) begin
            dir_idx_n = 2'd0;
            // If queue is empty after finishing all 4 directions for this node, next
            // cycle will detect and go to DONE.
          end else begin
            dir_idx_n = dir_idx + 2'd1;
          end

          // Update current row/col registers when not in first-dir cycle
          if (dir_idx != 2'd0) begin
            cur_row_n = eff_row;
            cur_col_n = eff_col;
          end
        end
      end

      DONE: begin
        // Stay one cycle with done=1 (handled in seq), then go to IDLE
        state_n = IDLE;
      end

      default: begin
        state_n = IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= IDLE;
      visited         <= 64'd0;
      left_budget     <= {192{1'b0}};
      right_budget    <= {192{1'b0}};
      q_head          <= 6'd0;
      q_tail          <= 6'd0;
      q_count         <= 6'd0;
      q_empty         <= 1'b1;
      cur_row         <= 3'd0;
      cur_col         <= 3'd0;
      dir_idx         <= 2'd0;
      reachable_count <= 6'd0;
      done            <= 1'b0;
      for (i = 0; i < 64; i = i + 1) begin
        queue[i] <= 6'd0;
      end
    end else begin
      state           <= state_n;
      visited         <= visited_n;
      left_budget     <= left_budget_n;
      right_budget    <= right_budget_n;
      q_head          <= q_head_n;
      q_tail          <= q_tail_n;
      q_count         <= q_count_n;
      q_empty         <= q_empty_n;
      cur_row         <= cur_row_n;
      cur_col         <= cur_col_n;
      dir_idx         <= dir_idx_n;
      reachable_count <= reachable_count_n;

      // Update queue sequentially
      for (i = 0; i < 64; i = i + 1) begin
        queue[i] <= queue_n[i];
      end

      // done: assert exactly one cycle when in DONE state
      if (state_n == DONE)
        done <= 1'b1;
      else
        done <= 1'b0;
    end
  end

endmodule