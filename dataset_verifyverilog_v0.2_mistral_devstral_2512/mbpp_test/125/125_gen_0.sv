module max_diff_substring (
  input clk,
  input rst_n,
  input start,
  input [7:0] binary_string,
  output reg [3:0] max_diff,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESS,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [2:0] index;
  reg [3:0] current_sum;
  reg [3:0] max_sum;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      index <= 0;
      current_sum <= 0;
      max_sum <= 0;
      max_diff <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    case (current_state)
      IDLE: begin
        if (start) next_state = PROCESS;
        else next_state = IDLE;
      end
      PROCESS: begin
        if (index == 7) next_state = DONE;
        else next_state = PROCESS;
      end
      DONE: begin
        if (!start) next_state = IDLE;
        else next_state = DONE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      index <= 0;
      current_sum <= 0;
      max_sum <= 0;
    end else if (current_state == PROCESS) begin
      // Process current bit
      if (binary_string[index]) begin
        current_sum <= current_sum - 1;
      end else begin
        current_sum <= current_sum + 1;
      end

      // Reset current_sum if negative
      if (current_sum < 0) begin
        current_sum <= 0;
      end

      // Update max_sum
      if (current_sum > max_sum) begin
        max_sum <= current_sum;
      end

      // Increment index
      index <= index + 1;
    end else if (current_state == DONE) begin
      max_diff <= max_sum;
      done <= 1;
    end else if (current_state == IDLE && !start) begin
      done <= 0;
    end
  end

endmodule