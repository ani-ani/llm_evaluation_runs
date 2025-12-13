module monotonic_subgrid_counter(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // start computation
  input [1:0] r_in, // actual rows used (1-4)
  input [1:0] c_in, // actual columns used (1-4)
  input [15:0][4:0] grid, // flattened 4x4 grid (5-bit values per cell)
  output reg [7:0] count, // monotonic subgrid count
  output reg done // computation complete
);

  // Internal state encoding
  typedef enum logic [1:0] {
    S_IDLE  = 2'b00,
    S_RUN   = 2'b01,
    S_DONE  = 2'b10
  } state_t;

  state_t state, next_state;

  // Row/column masks iterate from 1..15 (non-empty subsets)
  reg [3:0] row_mask;
  reg [3:0] col_mask;

  // Indices for row/col monotonic checks
  reg [1:0] row_idx;       // 0..3
  reg [1:0] col_idx;       // 0..3
  reg [1:0] sr_idx;        // selected row index (compressed by mask)
  reg [1:0] sc_idx;        // selected col index (compressed by mask)

  // Flags for current subset
  reg subset_valid;        // respects r_in/c_in and non-empty
  reg row_checked_done;    // all rows processed
  reg col_checked_done;    // all cols processed

  // Monotonic direction flags for current subset
  reg rows_nondec_ok;
  reg rows_noninc_ok;
  reg cols_nondec_ok;
  reg cols_noninc_ok;

  // Per-row / per-col iteration control
  reg [1:0] cur_row_elem_cnt; // position within selected columns for row check
  reg [1:0] cur_col_elem_cnt; // position within selected rows for col check

  // Previous values for running comparisons
  reg [4:0] prev_row_val;
  reg [4:0] cur_row_val;
  reg [4:0] prev_col_val;
  reg [4:0] cur_col_val;

  // Working flags for current row/col being checked
  reg cur_row_nondec_ok;
  reg cur_row_noninc_ok;
  reg cur_col_nondec_ok;
  reg cur_col_noninc_ok;

  // Control: whether we are currently checking rows or columns for this subset
  typedef enum logic [1:0] {
    PHASE_ROWS = 2'b00,
    PHASE_COLS = 2'b01,
    PHASE_DONE = 2'b10
  } phase_t;

  phase_t phase;

  // Utility: limit masks using r_in/c_in (force bits beyond used rows/cols to 0)
  function automatic [3:0] limit_row_mask(input [3:0] m, input [1:0] r);
    case (r)
      2'd0: limit_row_mask = 4'b0000;
      2'd1: limit_row_mask = m & 4'b0001;
      2'd2: limit_row_mask = m & 4'b0011;
      2'd3: limit_row_mask = m & 4'b0111;
      default: limit_row_mask = m & 4'b1111;
    endcase
  endfunction

  function automatic [3:0] limit_col_mask(input [3:0] m, input [1:0] c);
    case (c)
      2'd0: limit_col_mask = 4'b0000;
      2'd1: limit_col_mask = m & 4'b0001;
      2'd2: limit_col_mask = m & 4'b0011;
      2'd3: limit_col_mask = m & 4'b0111;
      default: limit_col_mask = m & 4'b1111;
    endcase
  endfunction

  // Count number of set bits in 4-bit mask
  function automatic [2:0] popcount4(input [3:0] v);
    popcount4 = v[0] + v[1] + v[2] + v[3];
  endfunction

  // Map k-th selected index within mask to actual index [0..3]
  function automatic [1:0] select_index(input [3:0] mask, input [1:0] sel);
    integer i;
    integer cnt;
    begin
      cnt = 0;
      select_index = 2'd0;
      for (i = 0; i < 4; i = i + 1) begin
        if (mask[i]) begin
          if (cnt == sel) begin
            select_index = i[1:0];
          end
          cnt = cnt + 1;
        end
      end
    end
  endfunction

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_RUN;
      end
      S_RUN: begin
        // When all mask combinations processed, move to DONE
        if (row_mask == 4'd15 && col_mask == 4'd15 && phase == PHASE_DONE)
          next_state = S_DONE;
      end
      S_DONE: begin
        if (!start)
          next_state = S_IDLE;
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      count <= 8'd0;
      done <= 1'b0;
      row_mask <= 4'd1;
      col_mask <= 4'd1;
      phase <= PHASE_ROWS;
      rows_nondec_ok <= 1'b1;
      rows_noninc_ok <= 1'b1;
      cols_nondec_ok <= 1'b1;
      cols_noninc_ok <= 1'b1;
      row_idx <= 2'd0;
      col_idx <= 2'd0;
      cur_row_elem_cnt <= 2'd0;
      cur_col_elem_cnt <= 2'd0;
      cur_row_nondec_ok <= 1'b1;
      cur_row_noninc_ok <= 1'b1;
      cur_col_nondec_ok <= 1'b1;
      cur_col_noninc_ok <= 1'b1;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          count <= 8'd0;
          row_mask <= 4'd1;
          col_mask <= 4'd1;
          phase <= PHASE_ROWS;
          rows_nondec_ok <= 1'b1;
          rows_noninc_ok <= 1'b1;
          cols_nondec_ok <= 1'b1;
          cols_noninc_ok <= 1'b1;
          row_idx <= 2'd0;
          col_idx <= 2'd0;
          cur_row_elem_cnt <= 2'd0;
          cur_col_elem_cnt <= 2'd0;
          cur_row_nondec_ok <= 1'b1;
          cur_row_noninc_ok <= 1'b1;
          cur_col_nondec_ok <= 1'b1;
          cur_col_noninc_ok <= 1'b1;
        end

        S_RUN: begin
          done <= 1'b0;

          // Apply limits to masks for current iteration
          // (combinationally conceptual; used below via limited_* variables)
          // Determine if current subset is valid (non-empty after limiting)
          begin
            reg [3:0] lm_r;
            reg [3:0] lm_c;
            lm_r = limit_row_mask(row_mask, r_in);
            lm_c = limit_col_mask(col_mask, c_in);
            subset_valid = (lm_r != 4'b0000) && (lm_c != 4'b0000);
          end

          case (phase)
            PHASE_ROWS: begin
              reg [3:0] lm_r2;
              reg [3:0] lm_c2;
              lm_r2 = limit_row_mask(row_mask, r_in);
              lm_c2 = limit_col_mask(col_mask, c_in);

              if (!subset_valid) begin
                // Skip directly to PHASE_DONE for invalid subset
                phase <= PHASE_DONE;
              end else begin
                // Row-wise monotonic checks across all selected rows
                // Iterate rows one by one; within each, iterate selected columns
                if (row_idx >= 4) begin
                  // All rows processed
                  phase <= PHASE_COLS;
                  col_idx <= 2'd0;
                  cur_col_elem_cnt <= 2'd0;
                  cur_col_nondec_ok <= 1'b1;
                  cur_col_noninc_ok <= 1'b1;
                  cols_nondec_ok <= 1'b1;
                  cols_noninc_ok <= 1'b1;
                end else if (!lm_r2[row_idx]) begin
                  // Row not selected; move to next
                  row_idx <= row_idx + 2'd1;
                  cur_row_elem_cnt <= 2'd0;
                  cur_row_nondec_ok <= 1'b1;
                  cur_row_noninc_ok <= 1'b1;
                end else begin
                  // Process selected row_idx
                  if (cur_row_elem_cnt == 2'd0) begin
                    // Initialize with first selected column value
                    sc_idx = select_index(lm_c2, 2'd0);
                    prev_row_val <= grid[{row_idx, sc_idx}];
                    cur_row_elem_cnt <= 2'd1;
                    cur_row_nondec_ok <= 1'b1;
                    cur_row_noninc_ok <= 1'b1;
                  end else begin
                    if (cur_row_elem_cnt < popcount4(lm_c2)) begin
                      sc_idx = select_index(lm_c2, cur_row_elem_cnt[1:0]);
                      cur_row_val = grid[{row_idx, sc_idx}];
                      // Update directional flags for this row
                      if (cur_row_val < prev_row_val)
                        cur_row_nondec_ok <= 1'b0;
                      if (cur_row_val > prev_row_val)
                        cur_row_noninc_ok <= 1'b0;
                      prev_row_val <= cur_row_val;
                      cur_row_elem_cnt <= cur_row_elem_cnt + 2'd1;
                    end else begin
                      // End of this row: merge into global row flags
                      rows_nondec_ok <= rows_nondec_ok & cur_row_nondec_ok;
                      rows_noninc_ok <= rows_noninc_ok & cur_row_noninc_ok;
                      // Next row
                      row_idx <= row_idx + 2'd1;
                      cur_row_elem_cnt <= 2'd0;
                      cur_row_nondec_ok <= 1'b1;
                      cur_row_noninc_ok <= 1'b1;
                    end
                  end
                end
              end
            end

            PHASE_COLS: begin
              reg [3:0] lm_r3;
              reg [3:0] lm_c3;
              lm_r3 = limit_row_mask(row_mask, r_in);
              lm_c3 = limit_col_mask(col_mask, c_in);

              if (!subset_valid) begin
                phase <= PHASE_DONE;
              end else begin
                // Column-wise monotonic checks across all selected columns
                if (col_idx >= 4) begin
                  // All columns processed -> decide and go to PHASE_DONE
                  phase <= PHASE_DONE;
                end else if (!lm_c3[col_idx]) begin
                  // Column not selected; move to next
                  col_idx <= col_idx + 2'd1;
                  cur_col_elem_cnt <= 2'd0;
                  cur_col_nondec_ok <= 1'b1;
                  cur_col_noninc_ok <= 1'b1;
                end else begin
                  if (cur_col_elem_cnt == 2'd0) begin
                    // Initialize with first selected row value
                    sr_idx = select_index(lm_r3, 2'd0);
                    prev_col_val <= grid[{sr_idx, col_idx}];
                    cur_col_elem_cnt <= 2'd1;
                    cur_col_nondec_ok <= 1'b1;
                    cur_col_noninc_ok <= 1'b1;
                  end else begin
                    if (cur_col_elem_cnt < popcount4(lm_r3)) begin
                      sr_idx = select_index(lm_r3, cur_col_elem_cnt[1:0]);
                      cur_col_val = grid[{sr_idx, col_idx}];
                      // Update directional flags for this column
                      if (cur_col_val < prev_col_val)
                        cur_col_nondec_ok <= 1'b0;
                      if (cur_col_val > prev_col_val)
                        cur_col_noninc_ok <= 1'b0;
                      prev_col_val <= cur_col_val;
                      cur_col_elem_cnt <= cur_col_elem_cnt + 2'd1;
                    end else begin
                      // End of this column: merge into global col flags
                      cols_nondec_ok <= cols_nondec_ok & cur_col_nondec_ok;
                      cols_noninc_ok <= cols_noninc_ok & cur_col_noninc_ok;
                      // Next column
                      col_idx <= col_idx + 2'd1;
                      cur_col_elem_cnt <= 2'd0;
                      cur_col_nondec_ok <= 1'b1;
                      cur_col_noninc_ok <= 1'b1;
                    end
                  end
                end
              end
            end

            PHASE_DONE: begin
              // At this point, for valid subset, we have rows_*_ok and cols_*_ok
              if (subset_valid) begin
                if ((rows_nondec_ok || rows_noninc_ok) &&
                    (cols_nondec_ok || cols_noninc_ok)) begin
                  count <= count + 8'd1;
                end
              end

              // Prepare next subset
              if (col_mask != 4'd15) begin
                col_mask <= col_mask + 4'd1;
              end else begin
                col_mask <= 4'd1;
                if (row_mask != 4'd15)
                  row_mask <= row_mask + 4'd1;
                else
                  row_mask <= 4'd15; // stay; S_DONE will be reached by FSM
              end

              // Reset per-subset state for next iteration
              phase <= PHASE_ROWS;
              rows_nondec_ok <= 1'b1;
              rows_noninc_ok <= 1'b1;
              cols_nondec_ok <= 1'b1;
              cols_noninc_ok <= 1'b1;
              row_idx <= 2'd0;
              col_idx <= 2'd0;
              cur_row_elem_cnt <= 2'd0;
              cur_col_elem_cnt <= 2'd0;
              cur_row_nondec_ok <= 1'b1;
              cur_row_noninc_ok <= 1'b1;
              cur_col_nondec_ok <= 1'b1;
              cur_col_noninc_ok <= 1'b1;
            end

            default: begin
              phase <= PHASE_ROWS;
            end
          endcase
        end

        S_DONE: begin
          done <= 1'b1;
          // Hold count, wait for start to deassert then reassert for new run
        end

        default: begin
          // Safety reset-like defaults
          done <= 1'b0;
          count <= 8'd0;
          row_mask <= 4'd1;
          col_mask <= 4'd1;
          phase <= PHASE_ROWS;
        end
      endcase
    end
  end

endmodule