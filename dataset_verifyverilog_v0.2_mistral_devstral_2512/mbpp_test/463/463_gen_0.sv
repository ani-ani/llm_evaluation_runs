module max_product_subarray (
  input clk,
  input rst_n,
  input start,
  input [5:0] array_length,
  input [15:0] array_data [0:7],
  output reg [31:0] result,
  output reg done
);

  parameter ARRAY_MAX = 8;
  parameter Q_FORMAT = 16;
  parameter Q_SCALE = 65536;

  typedef enum logic [1:0] {
    IDLE,
    PROCESS_ELEMENT,
    UPDATE_RESULT,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [2:0] index;
  reg [31:0] max_ending_here;
  reg [31:0] min_ending_here;
  reg [31:0] max_so_far;
  reg any_positive;
  reg [31:0] current_value_q;
  reg [31:0] temp_max;
  reg [31:0] temp_min;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      index <= 0;
      max_ending_here <= 0;
      min_ending_here <= 0;
      max_so_far <= 0;
      any_positive <= 0;
      result <= 0;
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
        if (start) next_state = PROCESS_ELEMENT;
      end
      PROCESS_ELEMENT: begin
        next_state = UPDATE_RESULT;
      end
      UPDATE_RESULT: begin
        if (index == array_length - 1) begin
          next_state = DONE;
        end else begin
          next_state = PROCESS_ELEMENT;
        end
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      index <= 0;
      max_ending_here <= 0;
      min_ending_here <= 0;
      max_so_far <= 0;
      any_positive <= 0;
    end else if (current_state == PROCESS_ELEMENT) begin
      // Convert current element to Q16.16
      current_value_q = array_data[index] * Q_SCALE;

      // Check if current value is positive
      if (array_data[index] > 0) any_positive = 1;

      // Calculate new max and min
      temp_max = max_ending_here * current_value_q >> Q_FORMAT;
      temp_min = min_ending_here * current_value_q >> Q_FORMAT;

      if (current_value_q > 0) begin
        max_ending_here = $signed({temp_max[31:0], 16'b0});
        min_ending_here = $signed({temp_min[31:0], 16'b0});
      end else begin
        max_ending_here = $signed({temp_min[31:0], 16'b0});
        min_ending_here = $signed({temp_max[31:0], 16'b0});
      end

      // Compare with current value
      if (current_value_q > max_ending_here) begin
        max_ending_here = current_value_q;
      end
      if (current_value_q < min_ending_here) begin
        min_ending_here = current_value_q;
      end

      // Update global max
      if (max_ending_here > max_so_far) begin
        max_so_far = max_ending_here;
      end
    end else if (current_state == UPDATE_RESULT) begin
      index <= index + 1;
    end else if (current_state == DONE) begin
      // Final result handling
      if (!any_positive) begin
        result <= 0;
      end else begin
        result <= max_so_far;
      end
      done <= 1;
    end
  end

  // Reset done when returning to IDLE
  always @(posedge clk) begin
    if (current_state == IDLE && !start) begin
      done <= 0;
    end
  end

endmodule