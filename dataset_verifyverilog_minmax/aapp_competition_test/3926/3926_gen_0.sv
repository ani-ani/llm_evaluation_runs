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

  // BFS queue storage (64 entries of 6-bit cell index)
  reg [5:0] q[0:63];
  reg [6:0] q_head, q_tail;

  // Visited and move budget memories per cell
  reg [63:0] visited_d, visited_q;
  reg [2:0] left_budget_d[0:63];
  reg [2:0] right_budget_d[0:63];
  reg [2:0] left_budget_q[0:63];
  reg [2:0] right_budget_q[0:63];

  // State machine
  reg [1:0] state_d, state_q;
  localparam IDLE = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam DONE = 2'b10;

  // Helper function to pack a (row, col) into 6-bit index [5:0]
  function [5:0] idx;
    input [2:0] r, c;
    idx = {r, c}; // row * 8 + col (3 bits each)
  endfunction

  // Current cell index being processed (from head of queue)
  reg [5:0] cur_d, cur_q;

  // One-step registered updates for all state
  always_comb begin
    // Defaults
    state_d = state_q;
    done = 1'b0;
    cur_d = cur_q;
    q_head = q_head;
    q_tail = q_tail;
    visited_d = visited_q;
    reachable_count = reachable_count; // keep last value until updated

    // Move budget defaults
    for (int i = 0; i < 64; i++) begin
      left_budget_d[i] = left_budget_q[i];
      right_budget_d[i] = right_budget_q[i];
    end

    if (~rst_n) begin
      // Reset state and memory
      state_d = IDLE;
      done = 1'b0;
      cur_d = 6'd0;
      q_head = 7'd0;
      q_tail = 7'd0;
      visited_d = 64'd0;
      for (int i = 0; i < 64; i++) begin
        left_budget_d[i] = 3'd0;
        right_budget_d[i] = 3'd0;
      end
      reachable_count = 6'd0;
    end else begin
      case (state_q)
        IDLE: begin
          // Wait for start; initialize structures
          q_head = 7'd0;
          q_tail = 7'd0;
          visited_d = 64'd0;
          for (int i = 0; i < 64; i++) begin
            left_budget_d[i] = 3'd0;
            right_budget_d[i] = 3'd0;
          end
          reachable_count = 6'd0;
          if (start) begin
            // Check if start cell is free
            if (grid[idx(start_row, start_col)]) begin
              // Start is blocked: finish immediately
              state_d = DONE;
              done = 1'b1;
              cur_d = 6'd0;
            end else begin
              // Seed BFS queue with start cell
              q_head = 7'd0;
              q_tail = 7'd1;
              q[0] = idx(start_row, start_col);
              visited_d = 1 << idx(start_row, start_col);
              left_budget_d[idx(start_row, start_col)] = max_left;
              right_budget_d[idx(start_row, start_col)] = max_right;
              state_d = PROCESSING;
            end
          end
        end

        PROCESSING: begin
          if (q_head == q_tail) begin
            // Queue empty: computation complete
            state_d = DONE;
            done = 1'b1;
            reachable_count = $countones(visited_q);
            cur_d = 6'd0;
          end else begin
            // Process one cell from head (BFS order)
            cur_d = q[q_head];
            q_head = q_head + 1;

            // Decode position
            [2:0] cur_row = cur_q[5:3];
            [2:0] cur_col = cur_q[2:0];

            // Current cell's remaining budgets
            [2:0] remL = left_budget_q[cur_q];
            [2:0] remR = right_budget_q[cur_q];

            // Directions: up, down, left, right (up/down first as required)

            // Up
            if (cur_row != 3'd0) begin
              [2:0] r = cur_row - 1;
              [2:0] c = cur_col;
              [5:0] nid = idx(r, c);
              if (!grid[nid] && !visited_q[nid]) begin
                visited_d[nid] = 1'b1;
                left_budget_d[nid] = remL;
                right_budget_d[nid] = remR;
                q[q_tail] = nid;
                q_tail = q_tail + 1;
              end
            end

            // Down
            if (cur_row != 3'd7) begin
              [2:0] r = cur_row + 1;
              [2:0] c = cur_col;
              [5:0] nid = idx(r, c);
              if (!grid[nid] && !visited_q[nid]) begin
                visited_d[nid] = 1'b1;
                left_budget_d[nid] = remL;
                right_budget_d[nid] = remR;
                q[q_tail] = nid;
                q_tail = q_tail + 1;
              end
            end

            // Left
            if (cur_col != 3'd0 && remL != 3'd0) begin
              [2:0] r = cur_row;
              [2:0] c = cur_col - 1;
              [5:0] nid = idx(r, c);
              if (!grid[nid] && !visited_q[nid]) begin
                visited_d[nid] = 1'b1;
                left_budget_d[nid] = remL - 1;
                right_budget_d[nid] = remR;
                q[q_tail] = nid;
                q_tail = q_tail + 1;
              end
            end

            // Right
            if (cur_col != 3'd7 && remR != 3'd0) begin
              [2:0] r = cur_row;
              [2:0] c = cur_col + 1;
              [5:0] nid = idx(r, c);
              if (!grid[nid] && !visited_q[nid]) begin
                visited_d[nid] = 1'b1;
                left_budget_d[nid] = remL;
                right_budget_d[nid] = remR - 1;
                q[q_tail] = nid;
                q_tail = q_tail + 1;
              end
            end

            // Remain in processing
            state_d = PROCESSING;
          end
        end

        DONE: begin
          // done high for exactly one cycle; hold count until next start
          state_d = IDLE;
          done = 1'b1;
          cur_d = 6'd0;
          q_head = 7'd0;
          q_tail = 7'd0;
          visited_d = visited_q; // keep last results
          for (int i = 0; i < 64; i++) begin
            left_budget_d[i] = left_budget_q[i];
            right_budget_d[i] = right_budget_q[i];
          end
        end

        default: state_d = IDLE;
      endcase
    end
  end

  // Sequential update with non-blocking assignments
  always_ff @(posedge clk) begin
    state_q <= state_d;
    cur_q <= cur_d;
    q_head <= q_head;
    q_tail <= q_tail;
    visited_q <= visited_d;
    for (int i = 0; i < 64; i++) begin
      left_budget_q[i] <= left_budget_d[i];
      right_budget_q[i] <= right_budget_d[i];
    end
  end

endmodule
