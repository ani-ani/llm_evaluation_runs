module purification_solver (
  input clk,
  input rst_n,
  input start,
  input [3:0] grid_row_idx,
  input [3:0] grid_col_idx,
  input cell_type,
  output reg [1:0] result_row [0:3],
  output reg [1:0] result_col [0:3],
  output reg [2:0] result_count,
  output reg done,
  output reg valid
);

  // Internal state definitions
  typedef enum logic [1:0] {
    IDLE,
    LOAD_GRID,
    SOLVE,
    OUTPUT
  } state_t;

  state_t current_state, next_state;

  // Internal grid storage
  reg [3:0] grid [0:3][0:3];
  reg [3:0] row_idx;
  reg [3:0] col_idx;
  reg [3:0] load_counter;
  reg [3:0] solve_counter;
  reg [3:0] output_counter;

  // Solution tracking
  reg [1:0] temp_result_row [0:3];
  reg [1:0] temp_result_col [0:3];
  reg [2:0] temp_result_count;
  reg temp_valid;
  reg row_strategy_valid;
  reg col_strategy_valid;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      row_idx <= 0;
      col_idx <= 0;
      load_counter <= 0;
      solve_counter <= 0;
      output_counter <= 0;
      done <= 0;
      valid <= 0;
      result_count <= 0;
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
        if (load_counter == 15) next_state = SOLVE;
      end
      SOLVE: begin
        if (solve_counter == 49) next_state = OUTPUT;
      end
      OUTPUT: begin
        if (output_counter == 49) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Load grid logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      row_idx <= 0;
      col_idx <= 0;
      load_counter <= 0;
    end else if (current_state == LOAD_GRID) begin
      if (load_counter < 16) begin
        grid[grid_row_idx][grid_col_idx] <= cell_type;
        load_counter <= load_counter + 1;
      end
    end
  end

  // Solve logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      solve_counter <= 0;
      row_strategy_valid <= 0;
      col_strategy_valid <= 0;
      temp_valid <= 0;
      temp_result_count <= 0;
    end else if (current_state == SOLVE) begin
      if (solve_counter == 0) begin
        // Check row strategy
        row_strategy_valid = 1;
        for (int i = 0; i < 4; i++) begin
          reg has_dot = 0;
          for (int j = 0; j < 4; j++) begin
            if (!grid[i][j]) has_dot = 1;
          end
          if (!has_dot) row_strategy_valid = 0;
        end
        
        // Check column strategy
        col_strategy_valid = 1;
        for (int j = 0; j < 4; j++) begin
          reg has_dot = 0;
          for (int i = 0; i < 4; i++) begin
            if (!grid[i][j]) has_dot = 1;
          end
          if (!has_dot) col_strategy_valid = 0;
        end
        
        // Determine solution
        if (row_strategy_valid) begin
          temp_valid = 1;
          temp_result_count = 4;
          for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 4; j++) begin
              if (!grid[i][j]) begin
                temp_result_row[i] = i;
                temp_result_col[i] = j;
                break;
              end
            end
          end
        end else if (col_strategy_valid) begin
          temp_valid = 1;
          temp_result_count = 4;
          for (int j = 0; j < 4; j++) begin
            for (int i = 0; i < 4; i++) begin
              if (!grid[i][j]) begin
                temp_result_row[j] = i;
                temp_result_col[j] = j;
                break;
              end
            end
          end
        end else begin
          temp_valid = 0;
          temp_result_count = 0;
        end
      end
      solve_counter <= solve_counter + 1;
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      output_counter <= 0;
      done <= 0;
      valid <= 0;
    end else if (current_state == OUTPUT) begin
      if (output_counter == 49) begin
        done <= 1;
        valid <= temp_valid;
        result_count <= temp_result_count;
        for (int i = 0; i < 4; i++) begin
          result_row[i] <= temp_result_row[i];
          result_col[i] <= temp_result_col[i];
        end
      end
      output_counter <= output_counter + 1;
    end else begin
      done <= 0;
    end
  end

endmodule