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

  // Masks beyond r_in/c_in are forced to 0 (ignored).
  // row_mask: bit j -> row j is included (j=0..3)
  // col_mask: bit k -> col k is included (k=0..3)

  // FSM state
  typedef enum logic [1:0] {IDLE=2'b00, PROC=2'b01, DONE=2'b10} state_t;
  state_t state;

  logic [3:0] row_mask;
  logic [3:0] col_mask;

  // Compute number of rows/cols to use (1..4)
  logic [2:0] r_used; // 1..4
  logic [2:0] c_used; // 1..4
  assign r_used = r_in + 1;
  assign c_used = c_in + 1;

  // Extract a single cell from flattened grid (row i, col j)
  function [4:0] cell (input integer i, input integer j);
    cell = grid[i*4 + j][4:0];
  endfunction

  // Check if a specific row is monotonic across the selected columns.
  // A row is monotonic if all values are non-decreasing OR all are non-increasing.
  // Only columns in col_mask with bit 1 are considered.
  function bit row_is_monotonic (input integer row, input [3:0] col_mask);
    bit inc, dec;
    integer k;
    logic [4:0] prev, curr;
    inc = 1'b1;
    dec = 1'b1;
    prev = cell(row, 0);

    for (k = 0; k < 4; k = k + 1) begin
      if (col_mask[k]) begin
        curr = cell(row, k);
        if (curr < prev) inc = 1'b0;
        if (curr > prev) dec = 1'b0;
        prev = curr;
      end
    end
    row_is_monotonic = (inc | dec);
  endfunction

  // Check if a specific column is monotonic across the selected rows.
  // A column is monotonic if all values are non-decreasing OR all are non-increasing.
  // Only rows in row_mask with bit 1 are considered.
  function bit col_is_monotonic (input integer col, input [3:0] row_mask);
    bit inc, dec;
    integer k;
    logic [4:0] prev, curr;
    inc = 1'b1;
    dec = 1'b1;
    prev = cell(0, col);

    for (k = 0; k < 4; k = k + 1) begin
      if (row_mask[k]) begin
        curr = cell(k, col);
        if (curr < prev) inc = 1'b0;
        if (curr > prev) dec = 1'b0;
        prev = curr;
      end
    end
    col_is_monotonic = (inc | dec);
  endfunction

  // Evaluate current subgrid monotonicity:
  // - All selected rows must be individually monotonic across selected columns
  // - All selected columns must be individually monotonic across selected rows
  function bit subgrid_is_monotonic (input [3:0] row_mask, input [3:0] col_mask);
    integer r, c;
    bit all_rows_ok, all_cols_ok;
    all_rows_ok = 1'b1;
    all_cols_ok = 1'b1;

    // Check every selected row
    for (r = 0; r < 4; r = r + 1) begin
      if (row_mask[r]) begin
        if (!row_is_monotonic(r, col_mask)) begin
          all_rows_ok = 1'b0;
        end
      end
    end

    // Check every selected column
    for (c = 0; c < 4; c = c + 1) begin
      if (col_mask[c]) begin
        if (!col_is_monotonic(c, row_mask)) begin
          all_cols_ok = 1'b0;
        end
      end
    end

    subgrid_is_monotonic = (all_rows_ok & all_cols_ok);
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= IDLE;
      count    <= 8'h0;
      done     <= 1'b0;
      row_mask <= 4'b0;
      col_mask <= 4'b0;
    end else begin
      case (state)
        IDLE: begin
          count <= 8'h0;
          done  <= 1'b0;
          if (start) begin
            row_mask <= 4'b0001; // start at row_mask = 1 (only row0)
            col_mask <= 4'b0001; // start at col_mask = 1 (only col0)
            state    <= PROC;
          end else begin
            state    <= IDLE;
          end
        end

        PROC: begin
          // Evaluate current (row_mask, col_mask) if masks are within r_in/c_in
          if (row_mask != 4'b0 && col_mask != 4'b0) begin
            if ((row_mask & ~((1 << r_used) - 1)) == 4'b0 &&
                (col_mask & ~((1 << c_used) - 1)) == 4'b0) begin
              if (subgrid_is_monotonic(row_mask, col_mask)) begin
                count <= count + 1;
              end
            end
          end

          // Advance masks: for every row_mask, iterate col_mask from 1..15
          if (col_mask < 4'b1111) begin
            col_mask <= col_mask + 1;
          end else begin
            col_mask <= 4'b0001;
            if (row_mask < 4'b1111) begin
              row_mask <= row_mask + 1;
            end else begin
              state <= DONE;
            end
          end
        end

        DONE: begin
          done  <= 1'b1;
          count <= count; // count stable
          if (start) begin
            // Re-start on start=1 while in DONE
            row_mask <= 4'b0001;
            col_mask <= 4'b0001;
            count    <= 8'h0;
            done     <= 1'b0;
            state    <= PROC;
          end else begin
            state <= DONE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule
