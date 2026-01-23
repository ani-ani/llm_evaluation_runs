module max_element (
  input clk,
  input rst_n,
  input start,
  input [4:0] array_size,
  input [15:0] array_data [0:15],
  output reg [15:0] max_result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    INIT,
    COMPARE,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [3:0] index;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      index <= 0;
      max_result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
      if (current_state == INIT) begin
        max_result <= array_data[0];
      end else if (current_state == COMPARE && index < array_size) begin
        if (array_data[index] > max_result) begin
          max_result <= array_data[index];
        end
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = INIT;
        else next_state = IDLE;
      end
      INIT: begin
        if (array_size > 1) next_state = COMPARE;
        else next_state = DONE;
      end
      COMPARE: begin
        if (index == array_size - 1) next_state = DONE;
        else next_state = COMPARE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
        else next_state = DONE;
      end
    endcase
  end

  // Index counter
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      index <= 0;
    end else begin
      if (current_state == INIT) begin
        index <= 1;
      end else if (current_state == COMPARE && index < array_size - 1) begin
        index <= index + 1;
      end else if (current_state == DONE) begin
        index <= 0;
      end
    end
  end

  // Done signal
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
    end else begin
      if (current_state == DONE) done <= 1;
      else done <= 0;
    end
  end

endmodule