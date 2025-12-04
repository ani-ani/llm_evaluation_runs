module grasshopper_path(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start computation
  input [15:0] grid [0:15], // Flattened 4x4 grid (each element 16-bit petal count)
  input [1:0] init_row, // Initial row (0-3)
  input [1:0] init_col, // Initial column (0-3)
  output reg [3:0] max_flowers, // Maximum flowers visited (1-16)
  output reg done // High when computation complete
);
  // State machine states
  typedef enum logic [1:0] {IDLE = 2'b00, INIT = 2'b01, EXPLORE = 2'b10, DONE = 2'b11} state_t;
  state_t state, next_state;

  // Internal storage for the 4x4 grid
  reg [15:0] grid_r [0:3][0:3];

  // Visited flags for 4x4 cells
  reg visited [0:3][0:3];

  // DFS path stack (knight moves only)
  reg [1:0] path_r [0:15];
  reg [1:0] path_c [0:15];
  reg [3:0] path_len;         // number of cells in current path (1..16)
  reg [3:0] sp;               // stack pointer (points to top of stack index 0..15)
  reg [3:0] next_move_idx;    // which move to try next from the top of stack

  // Max path length found so far
  reg [3:0] max_len;

  // Cycle counter to bound worst-case latency
  reg [6:0] cycle_cnt; // supports up to 127 cycles
  parameter MAX_CYCLES = 7'd100;

  // Knight move offsets (r±1,c±2) and (r±2,c±1)
  function [7:0][3:0] get_moves;
    get_moves = '{
      4'sd1, 4'sd2,  // (r+1, c+2), (r+2, c+1)
      4'sd1, -4'sd2, // (r+1, c-2), (r+2, c-1)
      -4'sd1, 4'sd2, // (r-1, c+2), (r-2, c+1)
      -4'sd1, -4'sd2 // (r-1, c-2), (r-2, c-1)
    };
  endfunction

  // Helper to check valid move bounds
  function bit in_bounds(input [1:0] r, input [1:0] c);
    in_bounds = (r < 4) && (c < 4);
  endfunction

  // Next state and combinatorial update
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        done = 1'b0;
        if (start) next_state = INIT;
      end

      INIT: begin
        done = 1'b0;
        // After initialization is done in sequential block
        next_state = EXPLORE;
      end

      EXPLORE: begin
        done = 1'b0;
        if (cycle_cnt >= MAX_CYCLES) begin
          next_state = DONE;
        end else if (sp == 4'b0) begin
          // Stack empty means backtrack finished
          next_state = DONE;
        end
      end

      DONE: begin
        done = 1'b1;
        if (!start) next_state = IDLE; // allow restart
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential logic (state updates, DFS execution)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      max_flowers <= 4'b0;
      max_len <= 4'b0;
      path_len <= 4'b0;
      sp <= 4'b0;
      next_move_idx <= 4'b0;
      cycle_cnt <= 7'b0;
      // Clear visited and path stack
      for (int i = 0; i < 4; i++) begin
        for (int j = 0; j < 4; j++) begin
          visited[i][j] <= 1'b0;
        end
      end
      for (int k = 0; k < 16; k++) begin
        path_r[k] <= 2'b0;
        path_c[k] <= 2'b0;
      end
    end else begin
      // State transition
      state <= next_state;
      // Cycle counter increments when actively exploring (before DONE)
      if (state == EXPLORE && next_state == EXPLORE) begin
        if (cycle_cnt < MAX_CYCLES) cycle_cnt <= cycle_cnt + 1;
      end else if (next_state == INIT) begin
        cycle_cnt <= 7'b0;
      end

      case (next_state)
        IDLE: begin
          max_flowers <= 4'b0;
        end

        INIT: begin
          // Copy input grid to internal storage (row-major 0..3 rows, 0..3 cols)
          for (int r = 0; r < 4; r++) begin
            for (int c = 0; c < 4; c++) begin
              grid_r[r][c] <= grid[r*4 + c];
            end
          end

          // Reset visited and stack
          for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 4; j++) begin
              visited[i][j] <= 1'b0;
            end
          end
          for (int k = 0; k < 16; k++) begin
            path_r[k] <= 2'b0;
            path_c[k] <= 2'b0;
          end
          path_len <= 4'd1;   // starting cell counts as visited
          sp <= 4'd0;         // stack pointer to top of stack (valid entries 0..sp)
          next_move_idx <= 4'd0;
          max_len <= 4'd1;    // at least the starting cell is a path

          // Mark start position as visited and push onto stack
          path_r[sp] <= init_row;
          path_c[sp] <= init_col;
          visited[init_row][init_col] <= 1'b1;
        end

        EXPLORE: begin
          // Explore one step per cycle
          if (sp < 16 && path_len > 4'b0) begin
            // Current position at top of stack
            [1:0] cur_r = path_r[sp];
            [1:0] cur_c = path_c[sp];
            [15:0] cur_val = grid_r[cur_r][cur_c];

            bit found_next;
            found_next = 1'b0;

            // Try moves in a fixed order until we find a valid one or exhaust all 8
            if (next_move_idx < 4'd8) begin
              int dr = get_moves()[next_move_idx*2 +: 2][0];
              int dc = get_moves()[next_move_idx*2 +: 2][1];
              int nr = cur_r + dr;
              int nc = cur_c + dc;

              if (in_bounds(nr, nc) && !visited[nr][nc] && (grid_r[nr][nc] > cur_val)) begin
                // Valid move found: push it
                sp <= sp + 1;
                path_r[sp] <= nr[1:0];
                path_c[sp] <= nc[1:0];
                visited[nr][nc] <= 1'b1;
                path_len <= path_len + 1;
                next_move_idx <= 4'd0; // reset move index for new top
                // Update max length if we extended the path
                if ((path_len + 1) > max_len) begin
                  max_len <= path_len + 1;
                end
                found_next = 1'b1;
              end
            end

            // If we didn't find a next move at this index, advance to the next candidate
            if (!found_next) begin
              if (next_move_idx < 4'd7) begin
                next_move_idx <= next_move_idx + 1;
              end else begin
                // Exhausted all 8 moves from current cell -> backtrack
                visited[cur_r][cur_c] <= 1'b0;
                // If stack is not empty, pop
                if (sp > 4'b0) begin
                  sp <= sp - 1;
                  path_len <= path_len - 1;
                end else begin
                  // Last element popped (sp was 0), finished DFS
                  path_len <= 4'b0;
                end
                next_move_idx <= 4'd0; // will retry from new top next cycle if any
              end
            end
          end else begin
            // No path in progress (should not happen), finish
            sp <= 4'b0;
            path_len <= 4'b0;
            next_move_idx <= 4'd0;
          end
        end

        DONE: begin
          // Hold final result; wait for start to go low to return to IDLE
          max_flowers <= max_len;
        end
      endcase
    end
  end
endmodule
