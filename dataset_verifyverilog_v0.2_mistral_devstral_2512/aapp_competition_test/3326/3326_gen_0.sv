module monotonic_subgrids (
  input clk,
  input rst_n,
  input start,
  input [7:0] grid [0:3][0:3],
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    SETUP,
    CHECK_ROWS,
    CHECK_COLS,
    INCREMENT,
    DONE
  } state_t;

  state_t state;
  reg [1:0] row_idx, col_idx;
  reg [1:0] row_mask, col_mask;
  reg [1:0] row_cnt, col_cnt;
  reg [1:0] subgrid_rows [0:3], subgrid_cols [0:3];
  reg [1:0] subgrid_row_cnt, subgrid_col_cnt;
  reg row_monotonic, col_monotonic;
  reg [15:0] counter;
  reg [3:0] cycle_count;

  // Row and column selection
  reg [1:0] selected_rows [0:3];
  reg [1:0] selected_cols [0:3];
  reg [1:0] selected_row_cnt, selected_col_cnt;

  // Monotonicity check variables
  reg [7:0] row_values [0:3];
  reg [7:0] col_values [0:3];
  reg row_inc, row_dec;
  reg col_inc, col_dec;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 0;
      done <= 0;
      counter <= 0;
      cycle_count <= 0;
      row_idx <= 0;
      col_idx <= 0;
      row_mask <= 0;
      col_mask <= 0;
      row_cnt <= 0;
      col_cnt <= 0;
      subgrid_row_cnt <= 0;
      subgrid_col_cnt <= 0;
      selected_row_cnt <= 0;
      selected_col_cnt <= 0;
      row_monotonic <= 0;
      col_monotonic <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SETUP;
            counter <= 0;
            cycle_count <= 0;
            row_idx <= 0;
            col_idx <= 0;
            row_mask <= 0;
            col_mask <= 0;
            row_cnt <= 0;
            col_cnt <= 0;
            subgrid_row_cnt <= 0;
            subgrid_col_cnt <= 0;
            selected_row_cnt <= 0;
            selected_col_cnt <= 0;
            row_monotonic <= 0;
            col_monotonic <= 0;
          end
        end
        SETUP: begin
          // Initialize row and column masks
          if (row_mask == 0) begin
            row_mask <= 1;
            col_mask <= 1;
            state <= CHECK_ROWS;
          end
        end
        CHECK_ROWS: begin
          // Extract selected rows
          selected_row_cnt = 0;
          for (int i = 0; i < 4; i++) begin
            if (row_mask[i]) begin
              selected_rows[selected_row_cnt] = i;
              selected_row_cnt = selected_row_cnt + 1;
            end
          end
          
          // Check row monotonicity
          if (selected_row_cnt == 1) begin
            row_monotonic = 1;
          end else begin
            row_inc = 1;
            row_dec = 1;
            for (int i = 0; i < selected_row_cnt - 1; i++) begin
              row_inc = row_inc && (grid[selected_rows[i]][col_idx] < grid[selected_rows[i+1]][col_idx]);
              row_dec = row_dec && (grid[selected_rows[i]][col_idx] > grid[selected_rows[i+1]][col_idx]);
            end
            row_monotonic = row_inc || row_dec;
          end
          state <= CHECK_COLS;
        end
        CHECK_COLS: begin
          // Extract selected columns
          selected_col_cnt = 0;
          for (int i = 0; i < 4; i++) begin
            if (col_mask[i]) begin
              selected_cols[selected_col_cnt] = i;
              selected_col_cnt = selected_col_cnt + 1;
            end
          end
          
          // Check column monotonicity
          if (selected_col_cnt == 1) begin
            col_monotonic = 1;
          end else begin
            col_inc = 1;
            col_dec = 1;
            for (int i = 0; i < selected_col_cnt - 1; i++) begin
              col_inc = col_inc && (grid[row_idx][selected_cols[i]] < grid[row_idx][selected_cols[i+1]]);
              col_dec = col_dec && (grid[row_idx][selected_cols[i]] > grid[row_idx][selected_cols[i+1]]);
            end
            col_monotonic = col_inc || col_dec;
          end
          state <= INCREMENT;
        end
        INCREMENT: begin
          if (row_monotonic && col_monotonic) begin
            counter <= counter + 1;
          end
          
          // Update row and column masks
          if (col_mask == 15) begin
            if (row_mask == 15) begin
              state <= DONE;
            end else begin
              row_mask <= row_mask + 1;
              col_mask <= 1;
            end
          end else begin
            col_mask <= col_mask + 1;
          end
          
          if (state != DONE) begin
            state <= CHECK_ROWS;
          end
        end
        DONE: begin
          result <= counter;
          done <= 1;
          if (cycle_count == 100) begin
            done <= 0;
            state <= IDLE;
          end else begin
            cycle_count <= cycle_count + 1;
          end
        end
      endcase
    end
  end

endmodule