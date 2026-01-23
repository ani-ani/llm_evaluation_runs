module bonbon_arrangement (
  input clk,
  input rst_n,
  input start,
  input [3:0] count_a,
  input [3:0] count_b,
  input [3:0] count_c,
  output reg [31:0] grid_packed,
  output reg valid,
  output reg done
);

  // State definitions
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] SEARCH = 2'b01;
  localparam [1:0] VALID_STATE = 2'b10;
  localparam [1:0] COMPLETE = 2'b11;

  // Current state
  reg [1:0] state = IDLE;

  // Grid storage (16 cells, 2 bits each)
  reg [1:0] grid [0:15];

  // Current cell index (0-15)
  reg [3:0] cell_idx = 0;

  // Remaining counts
  reg [3:0] rem_a = 0;
  reg [3:0] rem_b = 0;
  reg [3:0] rem_c = 0;

  // Backtracking stack (stores cell index and previous value)
  reg [3:0] stack_ptr = 0;
  reg [3:0] stack_cell [0:15];
  reg [1:0] stack_val [0:15];

  // Helper function to check adjacency constraints
  function automatic bit is_valid_placement;
    input [3:0] idx;
    input [1:0] val;
    begin
      // Check left neighbor (same row, previous column)
      if (idx % 4 != 0) begin
        if (grid[idx - 1] == val) begin
          is_valid_placement = 0;
          return;
        end
      end

      // Check top neighbor (previous row, same column)
      if (idx >= 4) begin
        if (grid[idx - 4] == val) begin
          is_valid_placement = 0;
          return;
        end
      end

      is_valid_placement = 1;
    end
  endfunction

  // Helper function to check if all counts are zero
  function automatic bit counts_zero;
    begin
      counts_zero = (rem_a == 0 && rem_b == 0 && rem_c == 0);
    end
  endfunction

  // Main FSM logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all state
      state <= IDLE;
      cell_idx <= 0;
      rem_a <= 0;
      rem_b <= 0;
      rem_c <= 0;
      stack_ptr <= 0;
      valid <= 0;
      done <= 0;
      grid_packed <= 0;

      // Initialize grid to invalid value
      integer i;
      for (i = 0; i < 16; i = i + 1) begin
        grid[i] <= 2'b11; // Invalid value
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            // Initialize for new search
            rem_a <= count_a;
            rem_b <= count_b;
            rem_c <= count_c;
            cell_idx <= 0;
            stack_ptr <= 0;
            valid <= 0;
            done <= 0;
            grid_packed <= 0;

            // Initialize grid to invalid value
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
              grid[i] <= 2'b11;
            end

            state <= SEARCH;
          end
        end

        SEARCH: begin
          // Try placing A, B, or C in current cell
          bit placed = 0;

          // Try A if available
          if (!placed && rem_a > 0 && is_valid_placement(cell_idx, 2'b00)) begin
            grid[cell_idx] <= 2'b00;
            rem_a <= rem_a - 1;
            cell_idx <= cell_idx + 1;
            placed = 1;
          end

          // Try B if available
          if (!placed && rem_b > 0 && is_valid_placement(cell_idx, 2'b01)) begin
            grid[cell_idx] <= 2'b01;
            rem_b <= rem_b - 1;
            cell_idx <= cell_idx + 1;
            placed = 1;
          end

          // Try C if available
          if (!placed && rem_c > 0 && is_valid_placement(cell_idx, 2'b10)) begin
            grid[cell_idx] <= 2'b10;
            rem_c <= rem_c - 1;
            cell_idx <= cell_idx + 1;
            placed = 1;
          end

          // If no placement was made, backtrack
          if (!placed) begin
            if (cell_idx == 0) begin
              // No solution found
              state <= COMPLETE;
            end else begin
              // Backtrack to previous cell
              cell_idx <= cell_idx - 1;
              stack_ptr <= stack_ptr + 1;
              stack_cell[stack_ptr] <= cell_idx;
              stack_val[stack_ptr] <= grid[cell_idx];

              // Restore count
              case (grid[cell_idx])
                2'b00: rem_a <= rem_a + 1;
                2'b01: rem_b <= rem_b + 1;
                2'b10: rem_c <= rem_c + 1;
              endcase

              grid[cell_idx] <= 2'b11; // Mark as invalid
            end
          end else if (cell_idx == 15) begin
            // All cells filled, check if solution is valid
            state <= VALID_STATE;
          end
        end

        VALID_STATE: begin
          if (counts_zero()) begin
            // Valid solution found
            valid <= 1;
            // Pack the grid into output
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
              grid_packed[(i*2)+1:i*2] <= grid[i];
            end
          end else begin
            // Invalid solution (counts not zero)
            valid <= 0;
          end
          state <= COMPLETE;
        end

        COMPLETE: begin
          done <= 1;
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule