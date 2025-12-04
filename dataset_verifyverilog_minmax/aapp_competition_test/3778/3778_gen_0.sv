module boomerang_target_config (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [1:0] a_0,
  input [1:0] a_1,
  input [1:0] a_2,
  input [1:0] a_3,
  input [1:0] a_4,
  input [1:0] a_5,
  input [1:0] a_6,
  input [1:0] a_7,
  output reg valid,
  output reg failed,
  output reg [2:0] t_row,
  output reg [2:0] t_col,
  output reg t_valid,
  output reg done
);

  // Constants
  localparam COLS = 8;
  localparam ROWS = 8;
  localparam MAX_OUT = 16; // up to 2 per row * 8 rows
  localparam IDLE  = 2'b00;
  localparam SOLVE = 2'b01;
  localparam EMIT  = 2'b10;
  localparam DONE  = 2'b11;

  // State and storage
  reg [1:0] state;
  reg [2:0] col_idx;        // reverse-order iterator (n-1 -> 0)
  reg [2:0] emit_ptr;       // output index into targets memory
  reg [5:0] out_cnt;        // number of emitted targets (0..16)
  reg [4:0] out_total;      // total number of targets to emit
  reg solution_fail;        // internal failure flag
  reg [2:0] cap_rows;       // n_rows (1..8), 0 when n=0 (shouldn't happen per spec)

  // Algorithm state
  reg [1:0] row_counts [0:ROWS-1]; // remaining hits needed per row (0..3)
  reg [1:0] slots_left  [0:ROWS-1]; // how many targets we can still place in this row (0..2)
  reg       row_active  [0:ROWS-1]; // has non-zero remaining or still a slot
  reg [2:0] active_rows [0:ROWS-1]; // list of row indices with available slots (>0)
  reg [2:0] active_len;             // number of active rows in list

  // Targets memory
  reg [2:0] t_mem_row [0:MAX_OUT-1];
  reg [2:0] t_mem_col [0:MAX_OUT-1];

  // Edge-detect 'start'
  reg start_d1;
  wire start_pulse;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d1 <= 1'b0;
    end else begin
      start_d1 <= start;
    end
  end
  assign start_pulse = start && !start_d1;

  function [2:0] clamp3(input [3:0] x);
    // returns min(x, 3)
    clamp3 = (x > 3) ? 3 : x[2:0];
  endfunction

  function [2:0] max3(input [2:0] a, input [2:0] b);
    max3 = (a > b) ? a : b;
  endfunction

  // Main state machine and algorithm
  integer i, j;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Outputs
      valid   <= 1'b0;
      failed  <= 1'b0;
      t_row   <= 3'b0;
      t_col   <= 3'b0;
      t_valid <= 1'b0;
      done    <= 1'b0;
      // State
      state          <= IDLE;
      col_idx        <= 3'b0;
      emit_ptr       <= 3'b0;
      out_cnt        <= 6'b0;
      out_total      <= 5'b0;
      solution_fail  <= 1'b0;
      cap_rows       <= 3'b0;
      // Init algorithm storage
      for (i = 0; i < ROWS; i = i + 1) begin
        row_counts[i] <= 2'b0;
        slots_left[i] <= 2'b10; // 2 slots available initially
        row_active[i] <= 1'b0;
        active_rows[i] <= 3'b0;
      end
      active_len <= 3'b0;
      // Init targets memory
      for (i = 0; i < MAX_OUT; i = i + 1) begin
        t_mem_row[i] <= 3'b0;
        t_mem_col[i] <= 3'b0;
      end
    end else begin
      // Default outputs for this cycle (single-cycle pulses/holds are controlled below)
      t_valid <= 1'b0;
      done    <= 1'b0;
      valid   <= 1'b0;
      failed  <= 1'b0;

      case (state)
        IDLE: begin
          // Reset algorithm storage
          for (i = 0; i < ROWS; i = i + 1) begin
            row_counts[i] <= 2'b0;
            slots_left[i] <= 2'b10; // 2 slots
            row_active[i] <= 1'b0;
            active_rows[i] <= 3'b0;
          end
          active_len <= 3'b0;
          solution_fail <= 1'b0;
          out_total <= 5'b0;
          out_cnt   <= 6'b0;
          emit_ptr  <= 3'b0;
          col_idx   <= 3'b0;

          if (start_pulse) begin
            // Begin processing
            cap_rows <= (|n) ? n : 3'b0; // if n==0, keep 0
            state <= SOLVE;
          end else begin
            state <= IDLE;
          end
        end

        SOLVE: begin
          // Initialize rows from previous columns (c = col_idx + 1 to n-1)
          if (col_idx == 3'b0) begin
            // First column in reverse: initialize row state from all previous columns
            // Row active and counts are currently 0; we'll add counts for column 'col_idx' soon.
            // Nothing else to initialize here.
          end

          // Add current column's counts to row_counts and mark active rows
          if (col_idx < n) begin
            // Add column count to the corresponding row_counts
            case (col_idx)
              3'd0: row_counts[0] <= row_counts[0] + a_0;
              3'd1: row_counts[1] <= row_counts[1] + a_1;
              3'd2: row_counts[2] <= row_counts[2] + a_2;
              3'd3: row_counts[3] <= row_counts[3] + a_3;
              3'd4: row_counts[4] <= row_counts[4] + a_4;
              3'd5: row_counts[5] <= row_counts[5] + a_5;
              3'd6: row_counts[6] <= row_counts[6] + a_6;
              3'd7: row_counts[7] <= row_counts[7] + a_7;
              default: ;
            endcase
            // Mark rows as active if they have non-zero counts or still have slots
            // The row_active update happens below after increment.
            // Proceed to next state update
          end

          // After adding column, update active row list and slots_left (based on new row_counts)
          // Build active_rows list: rows with slots_left>0
          // Also fail early if any row needs more hits than 2*remaining columns for that row
          begin
            reg [3:0] cols_rem;   // remaining columns to process after current one
            reg [2:0] rows_total; // max slots left for each row: min(2, 2*cols_rem + current slots)
            reg [2:0] need;       // needed hits for row i
            reg [2:0] max_possible; // max we can still place for row i
            reg early_fail;
            early_fail = 1'b0;
            cols_rem = (n >= (col_idx + 1)) ? (n - (col_idx + 1)) : 4'b0;
            active_len <= 3'b0;
            for (i = 0; i < ROWS; i = i + 1) begin
              need = clamp3({1'b0, row_counts[i]});
              max_possible = max3(3'd2, cols_rem << 1); // 2*cols_rem, capped at 2
              // Determine slots_left: min(2, max_possible - need + slots_left_before)
              // But slots_left[i] already holds previous value, so recompute cleanly:
              if (need >= 3'd2) begin
                // Cannot need 3+ hits per row; fail early
                early_fail = 1'b1;
                slots_left[i] <= 2'b0;
                row_active[i] <= 1'b0;
              end else begin
                // We can place at most 2 per row total; ensure we don't exceed 2
                if (need > 2) begin
                  early_fail = 1'b1;
                  slots_left[i] <= 2'b0;
                  row_active[i] <= 1'b0;
                end else begin
                  // Ensure need <= 2 (we just checked) and slots_left <= 2
                  if (need >= 2) begin
                    // Need 2 or more; slots must be >= need, else fail
                    if (slots_left[i] < need) early_fail = 1'b1;
                    // If need == 2, slots_left must be >= 2 initially (or after prior allocations)
                    // slots_left[i] already accounts for prior allocations
                  end
                  // Update row_active and recompute slots_left[i] based on remaining need
                  // If need == 0, we can still keep the row as active if slots_left[i] > 0
                  // to allow future columns to use its slots. But to keep capacity tight, we don't.
                  if (need == 0) begin
                    row_active[i] <= 1'b0;
                    // keep slots unchanged for potential future use, but we won't select it
                    // However, we shouldn't exceed 2 total placements per row; if need==0, we don't need slots now.
                  end else begin
                    row_active[i] <= 1'b1;
                    // Keep slots as is (it already represents remaining capacity for this row)
                  end
                end
              end
            end
            // Build active list now: include rows that still have slots left and are within cap_rows
            for (i = 0; i < ROWS; i = i + 1) begin
              if (i < cap_rows) begin
                if (slots_left[i] > 0) begin
                  active_rows[active_len] <= i[2:0];
                  active_len <= active_len + 1;
                end
              end
            end
            if (early_fail) solution_fail <= 1'b1;
          end

          // Allocate targets for this column if it has any hits
          if (!solution_fail && col_idx < n) begin
            reg [1:0] a_sel;
            reg [2:0] best_row;
            a_sel = (col_idx == 0) ? a_0 :
                    (col_idx == 1) ? a_1 :
                    (col_idx == 2) ? a_2 :
                    (col_idx == 3) ? a_3 :
                    (col_idx == 4) ? a_4 :
                    (col_idx == 5) ? a_5 :
                    (col_idx == 6) ? a_6 :
                    (col_idx == 7) ? a_7 : 2'b0;

            if (a_sel > 0) begin
              // Choose rows with largest remaining counts, breaking ties with smaller row index
              best_row = 3'b0;
              begin
                reg [1:0] best_cnt;
                reg [2:0] best_idx;
                best_cnt = 2'b0;
                best_idx = 3'b0;
                for (j = 0; j < ROWS; j = j + 1) begin
                  if (j < cap_rows) begin
                    if (slots_left[j] > 0) begin
                      if (row_counts[j] > best_cnt) begin
                        best_cnt <= row_counts[j];
                        best_idx <= j[2:0];
                      end else if (row_counts[j] == best_cnt) begin
                        // tie-breaker: prefer smaller row index
                        if (j < best_idx) best_idx <= j[2:0];
                      end
                    end
                  end
                end
                best_row <= best_idx;
              end

              // Place one target at (best_row, col_idx)
              if (out_total < MAX_OUT) begin
                t_mem_row[out_total] <= best_row;
                t_mem_col[out_total] <= (col_idx < 8) ? col_idx : 3'b0;
                out_total <= out_total + 1;
              end
              // Update row state
              if (row_counts[best_row] == 0) begin
                // This shouldn't happen if best_row selection respected slots and counts
                solution_fail <= 1'b1;
              end else begin
                row_counts[best_row] <= row_counts[best_row] - 1;
              end
              slots_left[best_row] <= slots_left[best_row] - 1;
              // If slots_left becomes 0 or count becomes 0, this row may drop from active list next cycle
            end
          end

          // Move to next column (reverse order: n-1 down to 0)
          if (col_idx + 1 >= n) begin
            // Finished all columns
            // Final feasibility check: any row with positive count means unmet hits -> fail
            for (i = 0; i < ROWS; i = i + 1) begin
              if (i < cap_rows) begin
                if (row_counts[i] > 0) solution_fail <= 1'b1;
              end
            end
            // Move to EMIT or DONE (fail)
            if (solution_fail) begin
              state <= DONE;
            end else begin
              state <= EMIT;
              emit_ptr <= 3'b0;
              out_cnt  <= 6'b0;
            end
          end else begin
            col_idx <= col_idx + 1;
            state   <= SOLVE;
          end
        end

        EMIT: begin
          // Emit targets one per cycle, then assert done
          if (emit_ptr < out_total) begin
            t_row   <= t_mem_row[emit_ptr];
            t_col   <= t_mem_col[emit_ptr];
            t_valid <= 1'b1;
            emit_ptr <= emit_ptr + 1;
            out_cnt  <= out_cnt + 1;
            state    <= EMIT;
          end else begin
            // Finished emitting all targets
            state    <= DONE;
            t_valid  <= 1'b0;
          end
        end

        DONE: begin
          // Final cycle: report status and done pulse
          if (solution_fail) begin
            valid  <= 1'b0;
            failed <= 1'b1;
          end else begin
            valid  <= 1'b1;
            failed <= 1'b0;
          end
          done   <= 1'b1;
          state  <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
