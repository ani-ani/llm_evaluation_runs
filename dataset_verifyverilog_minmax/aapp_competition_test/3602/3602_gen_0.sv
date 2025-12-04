module lamp_illumination_checker(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // pulse to start computation
  input [2:0] grid_size, // n (max 4)
  input [2:0] lamp_reach, // r (<= n)
  input [2:0] num_lamps, // k (<=8)
  input [2:0] lamp_rows [0:7], // 8 lamp positions
  input [2:0] lamp_cols [0:7],
  output reg result, // 1=possible, 0=impossible
  output reg done // high when computation completes
);

  // Internal state and storage
  localparam MAX_N = 4;
  localparam MAX_K = 8;

  // State machine
  localparam ST_IDLE     = 3'b000;
  localparam ST_LOAD     = 3'b001;
  localparam ST_PUSH_ROW = 3'b010;
  localparam ST_CHECK    = 3'b011;
  localparam ST_PUSH_COL = 3'b100;
  localparam ST_BACKTRK  = 3'b101;
  localparam ST_DONE     = 3'b110;

  reg [2:0] state, next_state;

  // Loaded parameters
  reg [2:0] n_r, r_r, k_r;
  reg [2:0] rows_r [0:7];
  reg [2:0] cols_r [0:7];

  // Search stack and helpers
  reg [7:0] orient;     // bit per lamp: 0=row, 1=col
  reg [7:0] orient_nxt; // next orientation under test
  reg [2:0] ptr;        // next lamp index to assign (0..k)
  reg [2:0] ptr_nxt;

  // Occupancy maps: 4x4 grids, bit i*4+j -> cell(i,j)
  reg [15:0] row_occ [0:3]; // if a cell is covered by a row-oriented lamp
  reg [15:0] col_occ [0:3]; // if a cell is covered by a col-oriented lamp
  // Accumulators to help early conflict detection
  reg [15:0] cmap_acc; // union of column-oriented lamps (for pruning row attempts)
  // Shadow maps for backtracking
  reg [15:0] row_occ_shadow [0:3];
  reg [15:0] col_occ_shadow [0:3];

  // Conflict detected signal
  wire conflict;

  // Compute union of column occupancy per column (cmap_acc) from col_occ
  function [15:0] compute_cmap;
    input [15:0] c0, c1, c2, c3;
    compute_cmap = c0 | c1 | c2 | c3;
  endfunction
  assign compute_cmap = compute_cmap_tb; // Silence unused warning if not used
  wire [15:0] cmap_acc_comb;
  assign cmap_acc_comb = col_occ[0] | col_occ[1] | col_occ[2] | col_occ[3];

  // Update accumulator in always block
  always @(*) begin
    cmap_acc = cmap_acc_comb;
  end

  // Conflict if any cell is covered by >=2 lamps in the same direction
  wire [15:0] dup_row = (row_occ[0] & row_occ[0]) |
                        (row_occ[1] & row_occ[1]) |
                        (row_occ[2] & row_occ[2]) |
                        (row_occ[3] & row_occ[3]);
  wire [15:0] dup_col = (col_occ[0] & col_occ[0]) |
                        (col_occ[1] & col_occ[1]) |
                        (col_occ[2] & col_occ[2]) |
                        (col_occ[3] & col_occ[3]);
  assign conflict = (dup_row != 16'h0) || (dup_col != 16'h0);

  // Helper: compute bitmask of cells covered by lamp i if oriented as 'row' or 'col'
  function [15:0] row_mask;
    input [2:0] row;
    input [2:0] col;
    input [2:0] reach;
    input [2:0] n;
    integer j;
    begin
      row_mask = 16'h0;
      if (row < n) begin
        for (j = 0; j < 4; j = j + 1) begin
          if (j < n && j >= col && (j - col) < reach) begin
            row_mask = row_mask | (16'h1 << (row*4 + j));
          end
        end
      end
    end
  endfunction

  function [15:0] col_mask;
    input [2:0] row;
    input [2:0] col;
    input [2:0] reach;
    input [2:0] n;
    integer i;
    begin
      col_mask = 16'h0;
      if (col < n) begin
        for (i = 0; i < 4; i = i + 1) begin
          if (i < n && i >= row && (i - row) < reach) begin
            col_mask = col_mask | (16'h1 << (i*4 + col));
          end
        end
      end
    end
  endfunction

  // Try to apply orientation (0=row,1=col) for lamp 'ptr'.
  // Returns '1' if no conflict and maps updated; '0' if conflict.
  // Also saves shadow for backtracking.
  function try_apply;
    input [2:0] idx;    // lamp index
    input which;        // 0=row,1=col
    input [2:0] n;
    input [2:0] reach;
    input [2:0] rows [0:7];
    input [2:0] cols [0:7];
    inout [15:0] row_occ [0:3];
    inout [15:0] col_occ [0:3];
    inout [15:0] row_shadow [0:3];
    inout [15:0] col_shadow [0:3];
    reg [15:0] mask;
    reg [15:0] new_occ;
    reg [2:0] r, c;
    integer j;
    reg ok;
    begin
      r = rows[idx];
      c = cols[idx];
      ok = 1'b1;

      // Save shadow copy of maps (for backtracking)
      row_shadow[0] = row_occ[0];
      row_shadow[1] = row_occ[1];
      row_shadow[2] = row_occ[2];
      row_shadow[3] = row_occ[3];
      col_shadow[0] = col_occ[0];
      col_shadow[1] = col_occ[1];
      col_shadow[2] = col_occ[2];
      col_shadow[3] = col_occ[3];

      if (which == 1'b0) begin
        // Row orientation: mark cells (r, c..c+reach-1)
        mask = row_mask(r, c, reach, n);
        // conflict if any of these cells are already covered by a row-oriented lamp
        if ((row_occ[r] & mask) != 16'h0) ok = 1'b0;
        if (ok) begin
          // Additional pruning: any previous column-oriented lamp covers any of the cells in the same row range?
          // If so, conflict because same cell is illuminated by >1 lamp in the same direction (row).
          if ((cmap_acc_comb & mask) != 16'h0) ok = 1'b0;
        end
        if (ok) begin
          // No conflicts; update row occupancy
          row_occ[r] = row_occ[r] | mask;
        end
      end else begin
        // Column orientation: mark cells (r..r+reach-1, c)
        mask = col_mask(r, c, reach, n);
        // conflict if any of these cells are already covered by a column-oriented lamp
        if ((col_occ[c] & mask) != 16'h0) ok = 1'b0;
        if (ok) begin
          // Additional pruning: any previous row-oriented lamp covers any of the cells in the same col range?
          if ((row_occ[0] & mask) != 16'h0 ||
              (row_occ[1] & mask) != 16'h0 ||
              (row_occ[2] & mask) != 16'h0 ||
              (row_occ[3] & mask) != 16'h0) ok = 1'b0;
        end
        if (ok) begin
          col_occ[c] = col_occ[c] | mask;
        end
      end

      try_apply = ok;
    end
  endfunction

  // State machine sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= ST_IDLE;
      result <= 1'b0;
      done <= 1'b0;
      orient <= 8'h0;
      orient_nxt <= 8'h0;
      ptr <= 3'b0;
      ptr_nxt <= 3'b0;
      n_r <= 3'b0;
      r_r <= 3'b0;
      k_r <= 3'b0;
      row_occ[0] <= 16'h0;
      row_occ[1] <= 16'h0;
      row_occ[2] <= 16'h0;
      row_occ[3] <= 16'h0;
      col_occ[0] <= 16'h0;
      col_occ[1] <= 16'h0;
      col_occ[2] <= 16'h0;
      col_occ[3] <= 16'h0;
      cmap_acc <= 16'h0;
      row_occ_shadow[0] <= 16'h0;
      row_occ_shadow[1] <= 16'h0;
      row_occ_shadow[2] <= 16'h0;
      row_occ_shadow[3] <= 16'h0;
      col_occ_shadow[0] <= 16'h0;
      col_occ_shadow[1] <= 16'h0;
      col_occ_shadow[2] <= 16'h0;
      col_occ_shadow[3] <= 16'h0;
      rows_r[0] <= 3'b0; rows_r[1] <= 3'b0; rows_r[2] <= 3'b0; rows_r[3] <= 3'b0;
      rows_r[4] <= 3'b0; rows_r[5] <= 3'b0; rows_r[6] <= 3'b0; rows_r[7] <= 3'b0;
      cols_r[0] <= 3'b0; cols_r[1] <= 3'b0; cols_r[2] <= 3'b0; cols_r[3] <= 3'b0;
      cols_r[4] <= 3'b0; cols_r[5] <= 3'b0; cols_r[6] <= 3'b0; cols_r[7] <= 3'b0;
    end else begin
      state <= next_state;
      // defaults
      done <= 1'b0;
      ptr <= ptr_nxt;
      orient <= orient_nxt;

      case (state)
        ST_IDLE: begin
          if (start) begin
            // Load input parameters
            n_r <= grid_size;
            r_r <= lamp_reach;
            k_r <= num_lamps;
            rows_r[0] <= lamp_rows[0]; rows_r[1] <= lamp_rows[1]; rows_r[2] <= lamp_rows[2]; rows_r[3] <= lamp_rows[3];
            rows_r[4] <= lamp_rows[4]; rows_r[5] <= lamp_rows[5]; rows_r[6] <= lamp_rows[6]; rows_r[7] <= lamp_rows[7];
            cols_r[0] <= lamp_cols[0]; cols_r[1] <= lamp_cols[1]; cols_r[2] <= lamp_cols[2]; cols_r[3] <= lamp_cols[3];
            cols_r[4] <= lamp_cols[4]; cols_r[5] <= lamp_cols[5]; cols_r[6] <= lamp_cols[6]; cols_r[7] <= lamp_cols[7];
            // Clear maps
            row_occ[0] <= 16'h0; row_occ[1] <= 16'h0; row_occ[2] <= 16'h0; row_occ[3] <= 16'h0;
            col_occ[0] <= 16'h0; col_occ[1] <= 16'h0; col_occ[2] <= 16'h0; col_occ[3] <= 16'h0;
            cmap_acc <= 16'h0;
            orient_nxt <= 8'h0;
            ptr_nxt <= 3'b0;
          end
        end

        ST_LOAD: begin
          // Start processing; ptr = 0
          ptr_nxt <= 3'b0;
          orient_nxt <= 8'h0;
        end

        ST_PUSH_ROW: begin
          // Try to assign current lamp (ptr) to row orientation
          if (try_apply(ptr, 1'b0, n_r, r_r, rows_r, cols_r, row_occ, col_occ, row_occ_shadow, col_occ_shadow)) begin
            orient_nxt[ptr] <= 1'b0;
            ptr_nxt <= ptr + 1;
          end else begin
            // Restore shadow (maps unchanged)
            row_occ[0] <= row_occ_shadow[0];
            row_occ[1] <= row_occ_shadow[1];
            row_occ[2] <= row_occ_shadow[2];
            row_occ[3] <= row_occ_shadow[3];
            col_occ[0] <= col_occ_shadow[0];
            col_occ[1] <= col_occ_shadow[1];
            col_occ[2] <= col_occ_shadow[2];
            col_occ[3] <= col_occ_shadow[3];
            // Fall through to try column
          end
        end

        ST_CHECK: begin
          if (conflict) begin
            // Current path is invalid; need to backtrack
            // Restore to snapshot before this lamp (shadow already reflects previous state)
            row_occ[0] <= row_occ_shadow[0];
            row_occ[1] <= row_occ_shadow[1];
            row_occ[2] <= row_occ_shadow[2];
            row_occ[3] <= row_occ_shadow[3];
            col_occ[0] <= col_occ_shadow[0];
            col_occ[1] <= col_occ_shadow[1];
            col_occ[2] <= col_occ_shadow[2];
            col_occ[3] <= col_occ_shadow[3];
          end
        end

        ST_PUSH_COL: begin
          // Try to assign current lamp (ptr) to column orientation
          if (try_apply(ptr, 1'b1, n_r, r_r, rows_r, cols_r, row_occ, col_occ, row_occ_shadow, col_occ_shadow)) begin
            orient_nxt[ptr] <= 1'b1;
            ptr_nxt <= ptr + 1;
          end else begin
            // Cannot place lamp in either orientation -> backtrack
            // Restore maps (shadow already saved at ST_PUSH_ROW)
            row_occ[0] <= row_occ_shadow[0];
            row_occ[1] <= row_occ_shadow[1];
            row_occ[2] <= row_occ_shadow[2];
            row_occ[3] <= row_occ_shadow[3];
            col_occ[0] <= col_occ_shadow[0];
            col_occ[1] <= col_occ_shadow[1];
            col_occ[2] <= col_occ_shadow[2];
            col_occ[3] <= col_occ_shadow[3];
            // Move to backtrack state (ptr will be decremented in BACKTRK)
          end
        end

        ST_BACKTRK: begin
          if (ptr == 3'b0) begin
            // Exhausted all possibilities -> impossible
            result <= 1'b0;
            done <= 1'b1;
          end else begin
            // Decrement ptr and flip the last decision to try the other orientation
            ptr_nxt <= ptr - 1;
            if (orient[ptr-1] == 1'b0) begin
              // Previously tried row, now try column at same level
              orient_nxt <= (orient & ~(8'h1 << (ptr-1))) | (1'b1 << (ptr-1));
            end else begin
              // Previously tried column, now backtrack further (no flip)
              orient_nxt <= (orient & ~(8'h1 << (ptr-1)));
            end
          end
        end

        ST_DONE: begin
          done <= 1'b1;
        end

        default: begin
          // no-op
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      ST_IDLE: begin
        if (start) next_state = ST_LOAD;
      end
      ST_LOAD: begin
        next_state = ST_PUSH_ROW;
      end
      ST_PUSH_ROW: begin
        // If previous apply succeeded, go to check; else go try column (maps restored in this state)
        if (!conflict) begin
          // We detect success or failure only on the next cycle; stay here for one cycle to evaluate conflict
          next_state = ST_CHECK;
        end else begin
          // immediate failure -> try column orientation
          next_state = ST_PUSH_COL;
        end
      end
      ST_CHECK: begin
        if (conflict) begin
          next_state = ST_PUSH_COL; // try column for this lamp
        end else begin
          // No conflict, move to next lamp if any
          if (ptr < k_r) next_state = ST_PUSH_ROW;
          else next_state = ST_DONE; // all lamps assigned without conflict
        end
      end
      ST_PUSH_COL: begin
        if (!conflict) begin
          next_state = ST_CHECK;
        end else begin
          next_state = ST_BACKTRK; // cannot place this lamp -> backtrack
        end
      end
      ST_BACKTRK: begin
        if (ptr == 3'b0) begin
          next_state = ST_DONE;
        end else begin
          if (orient[ptr-1] == 1'b0) begin
            // now try column at this level
            next_state = ST_PUSH_COL;
          end else begin
            // flipped from col already, backtrack further
            next_state = ST_BACKTRK;
          end
        end
      end
      ST_DONE: begin
        next_state = ST_DONE; // stay here until reset
      end
      default: next_state = ST_IDLE;
    endcase
  end

  // Result capture when solution found
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 1'b0;
    end else begin
      if (state == ST_CHECK && !conflict && ptr == k_r) begin
        result <= 1'b1; // found a conflict-free assignment
      end
    end
  end

endmodule
