module stamp_verification (
  input clk,
  input rst_n,
  input start,
  input [1:0] row_idx,
  input [1:0] col_idx,
  input [1:0] target_color,
  output reg result,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    LOAD_GRID,
    CHECK_A,
    CHECK_B,
    CHECK_C,
    CHECK_D,
    VALID,
    INVALID
  } state_t;

  state_t current_state, next_state;

  // Grid storage (4x4)
  reg [1:0] grid [0:3][0:3];

  // Counters
  reg [1:0] row_counter;
  reg [1:0] col_counter;
  reg [4:0] cycle_counter;

  // Consistency flags
  reg stamp_a_consistent;
  reg stamp_b_consistent;
  reg stamp_c_consistent;
  reg stamp_d_consistent;

  // Stamp coverage checks
  reg [1:0] stamp_a_color;
  reg [1:0] stamp_b_color;
  reg [1:0] stamp_c_color;
  reg [1:0] stamp_d_color;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result <= 0;
      done <= 0;
      row_counter <= 0;
      col_counter <= 0;
      cycle_counter <= 0;
      stamp_a_consistent <= 0;
      stamp_b_consistent <= 0;
      stamp_c_consistent <= 0;
      stamp_d_consistent <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = LOAD_GRID;
      end
      LOAD_GRID: begin
        if (row_counter == 3 && col_counter == 3) begin
          next_state = CHECK_A;
        end
      end
      CHECK_A: begin
        if (cycle_counter == 1) next_state = CHECK_B;
      end
      CHECK_B: begin
        if (cycle_counter == 2) next_state = CHECK_C;
      end
      CHECK_C: begin
        if (cycle_counter == 3) next_state = CHECK_D;
      end
      CHECK_D: begin
        if (cycle_counter == 4) begin
          if (stamp_a_consistent && stamp_b_consistent && 
              stamp_c_consistent && stamp_d_consistent) begin
            next_state = VALID;
          end else begin
            next_state = INVALID;
          end
        end
      end
      VALID: begin
        result = 1;
        done = 1;
      end
      INVALID: begin
        result = 0;
        done = 1;
      end
      default: next_state = IDLE;
    endcase
  end

  // Grid loading logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      row_counter <= 0;
      col_counter <= 0;
    end else if (current_state == LOAD_GRID) begin
      if (row_idx == row_counter && col_idx == col_counter) begin
        grid[row_counter][col_counter] <= target_color;
        if (col_counter == 3) begin
          col_counter <= 0;
          if (row_counter == 3) begin
            row_counter <= 0;
          end else begin
            row_counter <= row_counter + 1;
          end
        end else begin
          col_counter <= col_counter + 1;
        end
      end
    end
  end

  // Consistency checking logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_counter <= 0;
      stamp_a_consistent <= 0;
      stamp_b_consistent <= 0;
      stamp_c_consistent <= 0;
      stamp_d_consistent <= 0;
    end else begin
      case (current_state)
        CHECK_A: begin
          if (cycle_counter == 0) begin
            // Check stamp A (0,0) to (2,2)
            stamp_a_color = grid[0][0];
            stamp_a_consistent = 1;
            // Check cells only covered by stamp A
            if (grid[0][0] != stamp_a_color || grid[0][1] != stamp_a_color ||
                grid[0][2] != stamp_a_color || grid[1][0] != stamp_a_color ||
                grid[2][0] != stamp_a_color) begin
              stamp_a_consistent = 0;
            end
            cycle_counter <= cycle_counter + 1;
          end
        end
        CHECK_B: begin
          if (cycle_counter == 1) begin
            // Check stamp B (0,1) to (2,3)
            stamp_b_color = grid[0][3];
            stamp_b_consistent = 1;
            // Check cells only covered by stamp B
            if (grid[0][3] != stamp_b_color || grid[1][3] != stamp_b_color ||
                grid[2][3] != stamp_b_color) begin
              stamp_b_consistent = 0;
            end
            cycle_counter <= cycle_counter + 1;
          end
        end
        CHECK_C: begin
          if (cycle_counter == 2) begin
            // Check stamp C (1,0) to (3,2)
            stamp_c_color = grid[3][0];
            stamp_c_consistent = 1;
            // Check cells only covered by stamp C
            if (grid[3][0] != stamp_c_color || grid[3][1] != stamp_c_color ||
                grid[3][2] != stamp_c_color) begin
              stamp_c_consistent = 0;
            end
            cycle_counter <= cycle_counter + 1;
          end
        end
        CHECK_D: begin
          if (cycle_counter == 3) begin
            // Check stamp D (1,1) to (3,3)
            stamp_d_color = grid[3][3];
            stamp_d_consistent = 1;
            // Check cells only covered by stamp D
            if (grid[3][3] != stamp_d_color) begin
              stamp_d_consistent = 0;
            end
            // Check overlapping regions
            // Center cells must match at least one stamp color
            if (grid[1][1] != stamp_a_color && grid[1][1] != stamp_b_color &&
                grid[1][1] != stamp_c_color && grid[1][1] != stamp_d_color) begin
              stamp_d_consistent = 0;
            end
            if (grid[1][2] != stamp_a_color && grid[1][2] != stamp_b_color &&
                grid[1][2] != stamp_c_color && grid[1][2] != stamp_d_color) begin
              stamp_d_consistent = 0;
            end
            if (grid[2][1] != stamp_a_color && grid[2][1] != stamp_b_color &&
                grid[2][1] != stamp_c_color && grid[2][1] != stamp_d_color) begin
              stamp_d_consistent = 0;
            end
            if (grid[2][2] != stamp_a_color && grid[2][2] != stamp_b_color &&
                grid[2][2] != stamp_c_color && grid[2][2] != stamp_d_color) begin
              stamp_d_consistent = 0;
            end
            cycle_counter <= cycle_counter + 1;
          end
        end
      endcase
    end
  end

  // Reset done signal when starting new computation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
    end else if (start) begin
      done <= 0;
    end
  end

endmodule