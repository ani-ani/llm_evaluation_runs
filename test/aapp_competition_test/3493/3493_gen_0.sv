module button_assigner(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start signal (pulse high to begin)
  input [15:0] grid, // Flattened 4x4 grid (rows of preferences)
  output reg [2:0] k, // Max valid assignments (0-4)
  output reg done // High when computation completes
);

  // State encoding
  localparam IDLE          = 2'b00;
  localparam FIND_MATCH    = 2'b01;
  localparam UPDATE_MATRIX = 2'b10;
  localparam DONE          = 2'b11;

  reg [1:0] state, next_state;

  // Adjacency matrix (4x4), row-major
  reg [15:0] adj;      // working adjacency (mutable)
  reg [15:0] adj_next;

  // Bookkeeping for matching
  reg [1:0] row_idx, row_idx_next;          // current row to process
  reg [1:0] scan_col, scan_col_next;        // scanning columns within a row
  reg [3:0] col_used, col_used_next;        // which columns are already matched
  reg [2:0] k_next;                         // next k

  reg       found;                          // internal: found candidate edge in FIND_MATCH
  reg       found_next;

  // Combinational next-state and control logic
  always @* begin
    // defaults
    next_state   = state;
    adj_next     = adj;
    row_idx_next = row_idx;
    scan_col_next= scan_col;
    col_used_next= col_used;
    k_next       = k;
    found_next   = 1'b0;

    case (state)
      IDLE: begin
        // Wait for start pulse; initialize on start
        if (start) begin
          next_state    = FIND_MATCH;
          adj_next      = grid;       // load initial adjacency from input grid
          row_idx_next  = 2'd0;
          scan_col_next = 2'd0;
          col_used_next = 4'b0000;
          k_next        = 3'd0;
        end
      end

      FIND_MATCH: begin
        // Try to find a match for current row_idx starting from scan_col
        // We scan columns 0..3 in priority order each time this state is entered.
        // This is implemented as a small combinational search.
        found_next = 1'b0;

        // Check columns 0..3 for an available edge and unused column
        if (!found_next && adj[{row_idx,2'b00}] && !col_used[0]) begin
          found_next        = 1'b1;
          scan_col_next     = 2'd0;
        end
        else if (!found_next && adj[{row_idx,2'b01}] && !col_used[1]) begin
          found_next        = 1'b1;
          scan_col_next     = 2'd1;
        end
        else if (!found_next && adj[{row_idx,2'b10}] && !col_used[2]) begin
          found_next        = 1'b1;
          scan_col_next     = 2'd2;
        end
        else if (!found_next && adj[{row_idx,2'b11}] && !col_used[3]) begin
          found_next        = 1'b1;
          scan_col_next     = 2'd3;
        end

        if (found_next) begin
          // Found a match candidate for this row; go update structures
          next_state = UPDATE_MATRIX;
        end else begin
          // No match for this row; move to next row or finish
          if (row_idx == 2'd3) begin
            next_state = DONE;
          end else begin
            row_idx_next  = row_idx + 2'd1;
            scan_col_next = 2'd0;
            next_state    = FIND_MATCH;
          end
        end
      end

      UPDATE_MATRIX: begin
        // Commit the chosen match: row_idx matched to scan_col
        // Update col_used and increment k
        col_used_next[scan_col] = 1'b1;
        k_next                  = k + 3'd1;

        // Optionally, clear row's edges and the column's edges (preference tracking)
        // Clear all edges from this row
        adj_next[{row_idx,2'b00}] = 1'b0;
        adj_next[{row_idx,2'b01}] = 1'b0;
        adj_next[{row_idx,2'b10}] = 1'b0;
        adj_next[{row_idx,2'b11}] = 1'b0;
        // Clear this column in all rows
        adj_next[{2'd0,scan_col}] = 1'b0;
        adj_next[{2'd1,scan_col}] = 1'b0;
        adj_next[{2'd2,scan_col}] = 1'b0;
        adj_next[{2'd3,scan_col}] = 1'b0;

        // Move to next row or done
        if (row_idx == 2'd3) begin
          next_state = DONE;
        end else begin
          row_idx_next  = row_idx + 2'd1;
          scan_col_next = 2'd0;
          next_state    = FIND_MATCH;
        end
      end

      DONE: begin
        // Hold result until next start
        if (start) begin
          // Allow retrigger: re-init for new computation
          next_state    = FIND_MATCH;
          adj_next      = grid;
          row_idx_next  = 2'd0;
          scan_col_next = 2'd0;
          col_used_next = 4'b0000;
          k_next        = 3'd0;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential state and register updates
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      adj       <= 16'b0;
      row_idx   <= 2'd0;
      scan_col  <= 2'd0;
      col_used  <= 4'b0000;
      k         <= 3'd0;
      done      <= 1'b0;
      found     <= 1'b0;
    end else begin
      state     <= next_state;
      adj       <= adj_next;
      row_idx   <= row_idx_next;
      scan_col  <= scan_col_next;
      col_used  <= col_used_next;
      k         <= k_next;
      found     <= found_next;

      // done flag control: high only in DONE state
      done      <= (next_state == DONE);
    end
  end

endmodule