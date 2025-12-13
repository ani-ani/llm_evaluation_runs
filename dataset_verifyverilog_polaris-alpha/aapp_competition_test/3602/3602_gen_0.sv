module lamp_illumination_checker(
  input clk,
  input rst_n,
  input start,
  input [2:0] grid_size,
  input [2:0] lamp_reach,
  input [2:0] num_lamps,
  input [2:0] lamp_rows [0:7],
  input [2:0] lamp_cols [0:7],
  output reg result,
  output reg done
);

  // Internal registers for latched inputs
  reg [2:0] g_n;
  reg [2:0] g_r;
  reg [2:0] g_k;
  reg [2:0] l_rows [0:7];
  reg [2:0] l_cols [0:7];

  // State encoding
  localparam [2:0]
    S_IDLE     = 3'd0,
    S_LOAD     = 3'd1,
    S_CHECK_ROW= 3'd2,
    S_CHECK_COL= 3'd3,
    S_EVAL     = 3'd4;

  reg [2:0] state, next_state;

  // Orientation enumeration: for k lamps, orientations 0..(2^k - 1)
  reg [7:0] orient_mask;        // current orientation pattern
  reg [7:0] orient_mask_next;
  reg [7:0] max_orient;         // (1<<g_k)-1

  // Conflict tracking per orientation
  reg conflict;                 // conflict for current orientation
  reg conflict_next;

  // Chosen orientation found
  reg solution_found;
  reg solution_found_next;

  // Lamp index for sequential checking
  reg [2:0] lamp_idx;
  reg [2:0] lamp_idx_next;

  // Grid scan indices
  reg [2:0] cell_row;
  reg [2:0] cell_row_next;
  reg [2:0] cell_col;
  reg [2:0] cell_col_next;

  // Count of lamps affecting current cell in its oriented direction
  reg [3:0] cell_count;
  reg [3:0] cell_count_next;

  // Derived wires
  wire [2:0] last_row = (g_n == 0) ? 3'd0 : (g_n - 1'b1);
  wire [2:0] last_col = (g_n == 0) ? 3'd0 : (g_n - 1'b1);

  // Orientation for current lamp: 0=row, 1=column
  wire lamp_orient = orient_mask[lamp_idx];

  // Sequential state / regs update
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      g_n <= 3'd0;
      g_r <= 3'd0;
      g_k <= 3'd0;
      for (i = 0; i < 8; i = i + 1) begin
        l_rows[i] <= 3'd0;
        l_cols[i] <= 3'd0;
      end
      orient_mask <= 8'd0;
      max_orient <= 8'd0;
      conflict <= 1'b0;
      solution_found <= 1'b0;
      lamp_idx <= 3'd0;
      cell_row <= 3'd0;
      cell_col <= 3'd0;
      cell_count <= 4'd0;
      result <= 1'b0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      orient_mask <= orient_mask_next;
      conflict <= conflict_next;
      solution_found <= solution_found_next;
      lamp_idx <= lamp_idx_next;
      cell_row <= cell_row_next;
      cell_col <= cell_col_next;
      cell_count <= cell_count_next;
      // Latched parameters updates only when loading
      if (state == S_IDLE && start) begin
        g_n <= grid_size;
        g_r <= lamp_reach;
        g_k <= num_lamps;
        for (i = 0; i < 8; i = i + 1) begin
          l_rows[i] <= lamp_rows[i];
          l_cols[i] <= lamp_cols[i];
        end
      end
      // max_orient computed right after LOAD state
      if (state == S_LOAD) begin
        if (g_k == 0)
          max_orient <= 8'd0;
        else
          max_orient <= (8'd1 << g_k) - 1'b1;
      end
      // Outputs updated in EVAL
      if (state == S_EVAL) begin
        result <= solution_found_next;
        done <= 1'b1;
      end else if (state == S_IDLE && start) begin
        done <= 1'b0;
        result <= 1'b0;
      end
    end
  end

  // Next-state and combinational logic
  always @* begin
    // Defaults
    next_state = state;
    orient_mask_next = orient_mask;
    conflict_next = conflict;
    solution_found_next = solution_found;
    lamp_idx_next = lamp_idx;
    cell_row_next = cell_row;
    cell_col_next = cell_col;
    cell_count_next = cell_count;

    case (state)
      // Wait for start
      S_IDLE: begin
        if (start) begin
          // Initialize search
          orient_mask_next = 8'd0; // first orientation: all row-based
          conflict_next = 1'b0;
          solution_found_next = 1'b0;
          lamp_idx_next = 3'd0;
          cell_row_next = 3'd0;
          cell_col_next = 3'd0;
          cell_count_next = 4'd0;
          next_state = S_LOAD;
        end
      end

      // Setup based on latched inputs
      S_LOAD: begin
        // Corner case: zero lamps -> always possible
        if (g_k == 0) begin
          solution_found_next = 1'b1;
          next_state = S_EVAL;
        end else begin
          // Move to checking rows under first orientation
          lamp_idx_next = 3'd0;
          conflict_next = 1'b0;
          cell_row_next = 3'd0;
          cell_col_next = 3'd0;
          cell_count_next = 4'd0;
          next_state = S_CHECK_ROW;
        end
      end

      // CHECK_ROW: for current orientation, scan cells and count row-based lamp hits
      S_CHECK_ROW: begin
        // If conflict already detected, skip to next orientation
        if (conflict) begin
          // Move to next orientation or evaluate
          if (orient_mask == max_orient || g_k == 0) begin
            next_state = S_EVAL;
          end else begin
            orient_mask_next = orient_mask + 1'b1;
            conflict_next = 1'b0;
            lamp_idx_next = 3'd0;
            cell_row_next = 3'd0;
            cell_col_next = 3'd0;
            cell_count_next = 4'd0;
            next_state = S_CHECK_ROW;
          end
        end else begin
          // Iterate through grid cells and lamps sequentially
          if (cell_row < g_n && cell_col < g_n) begin
            if (lamp_idx < g_k) begin
              // Evaluate current lamp contribution for this cell in row mode
              cell_count_next = cell_count;
              if (lamp_orient == 1'b0) begin
                // Row-oriented lamp: same row, within reach horizontally
                if (l_rows[lamp_idx] == cell_row) begin
                  // distance in column
                  if ((cell_col >= l_cols[lamp_idx]) && (cell_col - l_cols[lamp_idx] <= g_r)) begin
                    cell_count_next = cell_count + 1'b1;
                  end else if ((cell_col < l_cols[lamp_idx]) && (l_cols[lamp_idx] - cell_col <= g_r)) begin
                    cell_count_next = cell_count + 1'b1;
                  end
                end
              end
              // After last lamp for this cell, check conflict and advance
              if (lamp_idx == (g_k - 1'b1)) begin
                // Determine if conflict at this cell
                if (cell_count_next > 4'd1)
                  conflict_next = 1'b1;
                // Prepare for next cell
                cell_count_next = 4'd0;
                lamp_idx_next = 3'd0;
                if (cell_col == (g_n - 1'b1)) begin
                  cell_col_next = 3'd0;
                  if (cell_row == (g_n - 1'b1)) begin
                    // Completed all cells for row-check phase
                    // If no conflict so far, proceed to column-check
                    if (!conflict_next)
                      next_state = S_CHECK_COL;
                  end else begin
                    cell_row_next = cell_row + 1'b1;
                  end
                end else begin
                  cell_col_next = cell_col + 1'b1;
                end
              end else begin
                // Move to next lamp for this cell
                lamp_idx_next = lamp_idx + 1'b1;
              end
            end
          end else begin
            // Safety: if bounds exceeded, go to column check
            lamp_idx_next = 3'd0;
            cell_row_next = 3'd0;
            cell_col_next = 3'd0;
            cell_count_next = 4'd0;
            next_state = S_CHECK_COL;
          end
        end
      end

      // CHECK_COL: reuse similar scan but only for column-oriented lamps
      S_CHECK_COL: begin
        if (conflict) begin
          // Move to next orientation or evaluate
          if (orient_mask == max_orient || g_k == 0) begin
            next_state = S_EVAL;
          end else begin
            orient_mask_next = orient_mask + 1'b1;
            conflict_next = 1'b0;
            lamp_idx_next = 3'd0;
            cell_row_next = 3'd0;
            cell_col_next = 3'd0;
            cell_count_next = 4'd0;
            next_state = S_CHECK_ROW;
          end
        end else begin
          if (cell_row < g_n && cell_col < g_n) begin
            if (lamp_idx < g_k) begin
              cell_count_next = cell_count;
              if (lamp_orient == 1'b1) begin
                // Column-oriented lamp: same column, within reach vertically
                if (l_cols[lamp_idx] == cell_col) begin
                  if ((cell_row >= l_rows[lamp_idx]) && (cell_row - l_rows[lamp_idx] <= g_r)) begin
                    cell_count_next = cell_count + 1'b1;
                  end else if ((cell_row < l_rows[lamp_idx]) && (l_rows[lamp_idx] - cell_row <= g_r)) begin
                    cell_count_next = cell_count + 1'b1;
                  end
                end
              end
              if (lamp_idx == (g_k - 1'b1)) begin
                if (cell_count_next > 4'd1)
                  conflict_next = 1'b1;
                cell_count_next = 4'd0;
                lamp_idx_next = 3'd0;
                if (cell_col == (g_n - 1'b1)) begin
                  cell_col_next = 3'd0;
                  if (cell_row == (g_n - 1'b1)) begin
                    // Completed all cells for this orientation
                    if (!conflict_next) begin
                      // Found valid orientation
                      solution_found_next = 1'b1;
                      next_state = S_EVAL;
                    end else begin
                      // Try next orientation
                      if (orient_mask == max_orient) begin
                        next_state = S_EVAL;
                      end else begin
                        orient_mask_next = orient_mask + 1'b1;
                        conflict_next = 1'b0;
                        lamp_idx_next = 3'd0;
                        cell_row_next = 3'd0;
                        cell_col_next = 3'd0;
                        cell_count_next = 4'd0;
                        next_state = S_CHECK_ROW;
                      end
                    end
                  end else begin
                    cell_row_next = cell_row + 1'b1;
                  end
                end else begin
                  cell_col_next = cell_col + 1'b1;
                end
              end else begin
                lamp_idx_next = lamp_idx + 1'b1;
              end
            end
          end else begin
            // Safety: go to evaluation
            if (!conflict_next)
              solution_found_next = 1'b1;
            next_state = S_EVAL;
          end
        end
      end

      // EVALUATE: finalize result and wait until next start
      S_EVAL: begin
        // result/done driven in sequential block
        if (start) begin
          // Allow immediate restart
          next_state = S_LOAD;
          orient_mask_next = 8'd0;
          conflict_next = 1'b0;
          solution_found_next = 1'b0;
          lamp_idx_next = 3'd0;
          cell_row_next = 3'd0;
          cell_col_next = 3'd0;
          cell_count_next = 4'd0;
        end else begin
          // Once done, go idle when start deasserted
          next_state = S_IDLE;
        end
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule