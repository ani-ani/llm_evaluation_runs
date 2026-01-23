module find_first_occurrence (
  input clk,
  input rst_n,
  input start,
  input [3:0] target,
  input [7:0] array_element_0,
  input [7:0] array_element_1,
  input [7:0] array_element_2,
  input [7:0] array_element_3,
  input [7:0] array_element_4,
  input [7:0] array_element_5,
  input [7:0] array_element_6,
  input [7:0] array_element_7,
  output reg [3:0] result,
  output reg done,
  output reg found
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    SETUP,
    COMPARE,
    UPDATE,
    DONE
  } state_t;

  state_t state, next_state;
  reg [3:0] left, right, mid;
  reg [3:0] counter;
  reg [7:0] current_element;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      left <= 0;
      right <= 0;
      mid <= 0;
      counter <= 0;
      result <= 15;
      done <= 0;
      found <= 0;
    end else begin
      state <= next_state;
      if (state == SETUP) begin
        left <= 0;
        right <= 7;
        result <= 15;
        counter <= 0;
        done <= 0;
        found <= 0;
      end else if (state == UPDATE) begin
        if (current_element == target) begin
          result <= mid;
          found <= 1;
        end
        counter <= counter + 1;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = SETUP;
      end
      SETUP: next_state = COMPARE;
      COMPARE: next_state = UPDATE;
      UPDATE: begin
        if (left <= right && counter < 4) next_state = COMPARE;
        else next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Mid calculation and array element selection
  always @(*) begin
    mid = (left + right) >> 1;
    case (mid)
      0: current_element = array_element_0;
      1: current_element = array_element_1;
      2: current_element = array_element_2;
      3: current_element = array_element_3;
      4: current_element = array_element_4;
      5: current_element = array_element_5;
      6: current_element = array_element_6;
      7: current_element = array_element_7;
      default: current_element = 0;
    endcase
  end

  // Update logic for left and right bounds
  always @(*) begin
    if (state == UPDATE) begin
      if (current_element == target) begin
        right = mid - 1;
      end else if (target < current_element) begin
        right = mid - 1;
      end else begin
        left = mid + 1;
      end
    end
  end

  // Done signal
  always @(*) begin
    if (state == DONE) done = 1;
    else done = 0;
  end

endmodule