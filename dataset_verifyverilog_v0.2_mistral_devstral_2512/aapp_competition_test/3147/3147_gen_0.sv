module square_killer_finder (
  input clk,
  input rst_n,
  input start,
  input [15:0] matrix_row [15:0],
  output reg [4:0] max_size,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CHECK_SIZE,
    CHECK_POSITION,
    CHECK_SYMMETRY,
    DONE
  } state_t;

  state_t state, next_state;
  reg [3:0] current_size;
  reg [3:0] current_row;
  reg [3:0] current_col;
  reg [3:0] check_row;
  reg [3:0] check_col;
  reg [3:0] pair_counter;
  reg [3:0] total_pairs;
  reg symmetric;
  reg [4:0] found_size;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      max_size <= 0;
      done <= 0;
      current_size <= 0;
      current_row <= 0;
      current_col <= 0;
      check_row <= 0;
      check_col <= 0;
      pair_counter <= 0;
      total_pairs <= 0;
      symmetric <= 1;
      found_size <= 0;
    end else begin
      state <= next_state;
      if (state == CHECK_SYMMETRY && !symmetric) begin
        current_col <= current_col + 1;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = CHECK_SIZE;
          current_size = 16;
          found_size = 0;
          done = 0;
        end
      end
      CHECK_SIZE: begin
        if (current_size == 1) begin
          next_state = DONE;
          max_size = found_size;
          done = 1;
        end else begin
          current_row = 0;
          current_col = 0;
          next_state = CHECK_POSITION;
        end
      end
      CHECK_POSITION: begin
        if (current_row > 15 - current_size + 1) begin
          current_size = current_size - 1;
          next_state = CHECK_SIZE;
        end else if (current_col > 15 - current_size + 1) begin
          current_row = current_row + 1;
          current_col = 0;
        end else begin
          check_row = 0;
          check_col = 0;
          pair_counter = 0;
          total_pairs = (current_size * current_size + 1) / 2;
          symmetric = 1;
          next_state = CHECK_SYMMETRY;
        end
      end
      CHECK_SYMMETRY: begin
        if (!symmetric) begin
          next_state = CHECK_POSITION;
        end else if (pair_counter == total_pairs - 1) begin
          if (current_size > found_size) begin
            found_size = current_size;
          end
          next_state = CHECK_POSITION;
        end else begin
          if (check_col == current_size - 1 - check_row) begin
            // Diagonal element, skip comparison
            pair_counter = pair_counter + 1;
            check_col = check_col + 1;
            if (check_col == current_size) begin
              check_col = 0;
              check_row = check_row + 1;
            end
          end else begin
            // Compare symmetric pair
            if (matrix_row[current_row + check_row][current_col + check_col] != 
                matrix_row[current_row + current_size - 1 - check_row][current_col + current_size - 1 - check_col]) begin
              symmetric = 0;
            end
            pair_counter = pair_counter + 1;
            check_col = check_col + 1;
            if (check_col == current_size) begin
              check_col = 0;
              check_row = check_row + 1;
            end
          end
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
          done = 0;
        end
      end
    endcase
  end

endmodule