module magic_square_test (
  input clk,
  input rst_n,
  input start,
  input [7:0] matrix_cell_i,
  input [3:0] write_addr,
  input write_en,
  output reg result,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    LOAD_MATRIX,
    COMPUTE_ROWS,
    COMPUTE_COLS,
    COMPUTE_DIAG1,
    COMPUTE_DIAG2,
    CHECK_RESULT,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Matrix storage (4x4)
  reg [7:0] matrix [0:15];

  // Sum storage (8 sums: 4 rows, 4 cols, 2 diags)
  reg [9:0] sums [0:7];

  // Counters
  reg [3:0] row_counter;
  reg [3:0] col_counter;
  reg [3:0] load_counter;
  reg [3:0] check_counter;

  // Temporary sum computation
  reg [9:0] temp_sum;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result <= 0;
      done <= 0;
      load_counter <= 0;
      row_counter <= 0;
      col_counter <= 0;
      check_counter <= 0;
      temp_sum <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = LOAD_MATRIX;
      end
      LOAD_MATRIX: begin
        if (load_counter == 15) next_state = COMPUTE_ROWS;
      end
      COMPUTE_ROWS: begin
        if (row_counter == 3) next_state = COMPUTE_COLS;
      end
      COMPUTE_COLS: begin
        if (col_counter == 3) next_state = COMPUTE_DIAG1;
      end
      COMPUTE_DIAG1: next_state = COMPUTE_DIAG2;
      COMPUTE_DIAG2: next_state = CHECK_RESULT;
      CHECK_RESULT: begin
        if (check_counter == 7) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Matrix loading
  always @(posedge clk) begin
    if (!rst_n) begin
      load_counter <= 0;
    end else if (current_state == LOAD_MATRIX && write_en) begin
      matrix[write_addr] <= matrix_cell_i;
      load_counter <= load_counter + 1;
    end
  end

  // Row sum computation
  always @(posedge clk) begin
    if (!rst_n) begin
      row_counter <= 0;
      temp_sum <= 0;
    end else if (current_state == COMPUTE_ROWS) begin
      if (row_counter == 0) begin
        temp_sum <= matrix[0] + matrix[1] + matrix[2] + matrix[3];
        sums[0] <= temp_sum;
        row_counter <= row_counter + 1;
      end else if (row_counter == 1) begin
        temp_sum <= matrix[4] + matrix[5] + matrix[6] + matrix[7];
        sums[1] <= temp_sum;
        row_counter <= row_counter + 1;
      end else if (row_counter == 2) begin
        temp_sum <= matrix[8] + matrix[9] + matrix[10] + matrix[11];
        sums[2] <= temp_sum;
        row_counter <= row_counter + 1;
      end else if (row_counter == 3) begin
        temp_sum <= matrix[12] + matrix[13] + matrix[14] + matrix[15];
        sums[3] <= temp_sum;
        row_counter <= row_counter + 1;
      end
    end
  end

  // Column sum computation
  always @(posedge clk) begin
    if (!rst_n) begin
      col_counter <= 0;
      temp_sum <= 0;
    end else if (current_state == COMPUTE_COLS) begin
      if (col_counter == 0) begin
        temp_sum <= matrix[0] + matrix[4] + matrix[8] + matrix[12];
        sums[4] <= temp_sum;
        col_counter <= col_counter + 1;
      end else if (col_counter == 1) begin
        temp_sum <= matrix[1] + matrix[5] + matrix[9] + matrix[13];
        sums[5] <= temp_sum;
        col_counter <= col_counter + 1;
      end else if (col_counter == 2) begin
        temp_sum <= matrix[2] + matrix[6] + matrix[10] + matrix[14];
        sums[6] <= temp_sum;
        col_counter <= col_counter + 1;
      end else if (col_counter == 3) begin
        temp_sum <= matrix[3] + matrix[7] + matrix[11] + matrix[15];
        sums[7] <= temp_sum;
        col_counter <= col_counter + 1;
      end
    end
  end

  // Diagonal 1 computation
  always @(posedge clk) begin
    if (!rst_n) begin
      temp_sum <= 0;
    end else if (current_state == COMPUTE_DIAG1) begin
      temp_sum <= matrix[0] + matrix[5] + matrix[10] + matrix[15];
      sums[0] <= temp_sum;
    end
  end

  // Diagonal 2 computation
  always @(posedge clk) begin
    if (!rst_n) begin
      temp_sum <= 0;
    end else if (current_state == COMPUTE_DIAG2) begin
      temp_sum <= matrix[3] + matrix[6] + matrix[9] + matrix[12];
      sums[1] <= temp_sum;
    end
  end

  // Result checking
  always @(posedge clk) begin
    if (!rst_n) begin
      check_counter <= 0;
      result <= 0;
    end else if (current_state == CHECK_RESULT) begin
      if (check_counter == 0) begin
        result <= (sums[0] == sums[1]);
        check_counter <= check_counter + 1;
      end else if (check_counter == 1) begin
        result <= result && (sums[0] == sums[2]);
        check_counter <= check_counter + 1;
      end else if (check_counter == 2) begin
        result <= result && (sums[0] == sums[3]);
        check_counter <= check_counter + 1;
      end else if (check_counter == 3) begin
        result <= result && (sums[0] == sums[4]);
        check_counter <= check_counter + 1;
      end else if (check_counter == 4) begin
        result <= result && (sums[0] == sums[5]);
        check_counter <= check_counter + 1;
      end else if (check_counter == 5) begin
        result <= result && (sums[0] == sums[6]);
        check_counter <= check_counter + 1;
      end else if (check_counter == 6) begin
        result <= result && (sums[0] == sums[7]);
        check_counter <= check_counter + 1;
      end
    end
  end

  // Done signal
  always @(posedge clk) begin
    if (!rst_n) begin
      done <= 0;
    end else if (current_state == DONE) begin
      done <= 1;
    end else if (current_state == IDLE) begin
      done <= 0;
    end
  end

endmodule