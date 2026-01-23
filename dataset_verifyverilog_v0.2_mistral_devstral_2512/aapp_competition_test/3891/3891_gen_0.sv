module black_square_center (
  input clk,
  input rst_n,
  input start,
  input cell_valid,
  input cell_is_black,
  input [7:0] row_index,
  input [7:0] col_index,
  output reg [7:0] center_row,
  output reg [7:0] center_col,
  output reg done
);

  // Parameters
  parameter N_ROWS = 8;
  parameter N_COLS = 8;
  parameter TOTAL_CELLS = N_ROWS * N_COLS;

  // FSM states
  typedef enum logic [1:0] {
    IDLE,
    SCANNING,
    CALCULATING,
    DONE
  } state_t;

  // State registers
  state_t current_state, next_state;
  reg [7:0] min_row, min_col;
  reg [7:0] max_row, max_col;
  reg [7:0] cell_counter;

  // Initialize registers
  initial begin
    current_state = IDLE;
    min_row = 8'hFF;
    min_col = 8'hFF;
    max_row = 8'h00;
    max_col = 8'h00;
    cell_counter = 8'h00;
    center_row = 8'h00;
    center_col = 8'h00;
    done = 1'b0;
  end

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      min_row <= 8'hFF;
      min_col <= 8'hFF;
      max_row <= 8'h00;
      max_col <= 8'h00;
      cell_counter <= 8'h00;
      center_row <= 8'h00;
      center_col <= 8'h00;
      done <= 1'b0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = SCANNING;
      end
      SCANNING: begin
        if (cell_counter == TOTAL_CELLS - 1) next_state = CALCULATING;
      end
      CALCULATING: begin
        next_state = DONE;
      end
      DONE: begin
        if (start) next_state = SCANNING;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      min_row <= 8'hFF;
      min_col <= 8'hFF;
      max_row <= 8'h00;
      max_col <= 8'h00;
      cell_counter <= 8'h00;
    end else begin
      case (current_state)
        IDLE: begin
          min_row <= 8'hFF;
          min_col <= 8'hFF;
          max_row <= 8'h00;
          max_col <= 8'h00;
          cell_counter <= 8'h00;
        end
        SCANNING: begin
          if (cell_valid) begin
            if (cell_is_black) begin
              // Update min and max for rows
              if (row_index < min_row) min_row <= row_index;
              if (row_index > max_row) max_row <= row_index;
              // Update min and max for columns
              if (col_index < min_col) min_col <= col_index;
              if (col_index > max_col) max_col <= col_index;
            end
            cell_counter <= cell_counter + 1;
          end
        end
        CALCULATING: begin
          // Compute center coordinates (1-based)
          center_row <= (min_row + max_row) / 2 + 1;
          center_col <= (min_col + max_col) / 2 + 1;
        end
        DONE: begin
          if (start) begin
            min_row <= 8'hFF;
            min_col <= 8'hFF;
            max_row <= 8'h00;
            max_col <= 8'h00;
            cell_counter <= 8'h00;
          end
        end
      endcase
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
    end else begin
      case (current_state)
        DONE: done <= 1'b1;
        default: done <= 1'b0;
      endcase
    end
  end

endmodule