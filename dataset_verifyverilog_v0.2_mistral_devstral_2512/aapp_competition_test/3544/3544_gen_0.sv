module cinema_seating (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [7:0] num_groups_1,
  input [7:0] num_groups_2,
  input [7:0] num_groups_3,
  input [7:0] num_groups_4,
  input [7:0] num_groups_5,
  input [7:0] num_groups_6,
  input [7:0] num_groups_7,
  input [7:0] num_groups_8,
  output reg [4:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CALCULATE_X,
    CHECK_SEATING,
    DONE
  } state_t;

  state_t state;
  reg [3:0] x; // Current X being tested (1-12)
  reg [3:0] best_x; // Best X found
  reg [15:0] min_rows; // Minimum rows found
  reg [15:0] current_rows; // Current row count for this X
  reg [15:0] row_size; // Current row size (X - row_count)
  reg [7:0] remaining_groups [8:0]; // Groups remaining (index 0 unused)
  reg [2:0] group_idx; // Current group index being tried
  reg [15:0] row_remaining; // Remaining seats in current row
  reg [15:0] cycle_count; // Cycle counter for timeout

  // Initialize remaining groups
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      x <= 0;
      best_x <= 0;
      min_rows <= 16'hFFFF;
      current_rows <= 0;
      row_size <= 0;
      for (int i = 1; i <= 8; i++) begin
        remaining_groups[i] <= 0;
      end
      group_idx <= 0;
      row_remaining <= 0;
      cycle_count <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALCULATE_X;
            x <= 1;
            best_x <= 0;
            min_rows <= 16'hFFFF;
            cycle_count <= 0;
          end
        end
        CALCULATE_X: begin
          if (cycle_count >= 10000) begin
            state <= DONE;
            result <= 5'd13;
            done <= 1;
          end else if (x > 12) begin
            state <= DONE;
            if (best_x == 0) begin
              result <= 5'd13;
            end else begin
              result <= best_x;
            end
            done <= 1;
          end else begin
            // Initialize for this X
            current_rows <= 0;
            row_size <= x;
            remaining_groups[1] <= num_groups_1;
            remaining_groups[2] <= num_groups_2;
            remaining_groups[3] <= num_groups_3;
            remaining_groups[4] <= num_groups_4;
            remaining_groups[5] <= num_groups_5;
            remaining_groups[6] <= num_groups_6;
            remaining_groups[7] <= num_groups_7;
            remaining_groups[8] <= num_groups_8;
            group_idx <= 8;
            row_remaining <= row_size;
            state <= CHECK_SEATING;
          end
        end
        CHECK_SEATING: begin
          if (cycle_count >= 10000) begin
            state <= DONE;
            result <= 5'd13;
            done <= 1;
          end else begin
            // Check if all groups are seated
            reg all_seated = 1;
            for (int i = 1; i <= 8; i++) begin
              if (remaining_groups[i] != 0) begin
                all_seated = 0;
              end
            end

            if (all_seated) begin
              // Record this solution
              if (current_rows < min_rows || (current_rows == min_rows && x < best_x)) begin
                min_rows <= current_rows;
                best_x <= x;
              end
              // Move to next X
              state <= CALCULATE_X;
              x <= x + 1;
            end else if (row_size <= 0) begin
              // This X failed
              state <= CALCULATE_X;
              x <= x + 1;
            end else begin
              // Try to place groups in current row
              if (group_idx == 0) begin
                // No group could fit, move to next row
                current_rows <= current_rows + 1;
                row_size <= x - current_rows;
                row_remaining <= row_size;
                group_idx <= 8;
              end else begin
                // Try to place current group
                if (remaining_groups[group_idx] > 0 && group_idx <= row_remaining) begin
                  // Place group
                  remaining_groups[group_idx] <= remaining_groups[group_idx] - 1;
                  row_remaining <= row_remaining - group_idx - 1; // Group size + 1 empty seat
                  group_idx <= 8; // Reset to try largest groups again
                end else begin
                  group_idx <= group_idx - 1; // Try smaller group
                end
              end
            end
          end
        end
        DONE: begin
          // Stay in DONE until reset
        end
      endcase
    end
  end

  // Cycle counter
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_count <= 0;
    end else if (state != IDLE && state != DONE) begin
      cycle_count <= cycle_count + 1;
    end
  end

endmodule