module recursive_list_sum (
  input clk,
  input rst_n,
  input start,
  input [15:0] data [0:3][0:3],
  output reg [31:0] total_sum,
  output reg done
);

  // State machine states
  typedef enum logic [1:0] {
    IDLE,
    SUMMING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Counters for row and column
  reg [1:0] row_counter;
  reg [1:0] col_counter;

  // Accumulator
  reg [31:0] accumulator;

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      row_counter <= 0;
      col_counter <= 0;
      accumulator <= 0;
      total_sum <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = SUMMING;
          row_counter = 0;
          col_counter = 0;
          accumulator = 0;
        end
      end
      SUMMING: begin
        if (col_counter == 3 && row_counter == 3) begin
          next_state = DONE;
        end else if (col_counter == 3) begin
          row_counter = row_counter + 1;
          col_counter = 0;
        end else begin
          col_counter = col_counter + 1;
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end

  // Accumulation logic
  always @(posedge clk) begin
    if (!rst_n) begin
      accumulator <= 0;
    end else if (current_state == SUMMING) begin
      accumulator <= accumulator + data[row_counter][col_counter];
    end
  end

  // Output logic
  always @(posedge clk) begin
    if (!rst_n) begin
      total_sum <= 0;
      done <= 0;
    end else if (current_state == DONE) begin
      total_sum <= accumulator;
      done <= 1;
    end else begin
      done <= 0;
    end
  end

endmodule