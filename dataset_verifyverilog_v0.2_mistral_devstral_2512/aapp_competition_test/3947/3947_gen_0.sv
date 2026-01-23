module max_points_game (
  input clk,
  input rst_n,
  input start,
  input [15:0] data_in,
  input valid_in,
  input done_in,
  output reg [31:0] result,
  output reg done,
  output reg ready
);

  // Internal state machine
  typedef enum logic [2:0] {
    IDLE,
    LOAD,
    PROCESS,
    CALC_REMAINING,
    DONE
  } state_t;
  state_t state, next_state;

  // Internal buffer and stack
  reg [7:0] buffer [0:15];
  reg [3:0] buffer_idx;
  reg [7:0] stack [0:15];
  reg [3:0] stack_ptr;
  reg [31:0] score;
  reg [3:0] process_idx;
  reg [3:0] calc_idx;

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      buffer_idx <= 0;
      stack_ptr <= 0;
      score <= 0;
      process_idx <= 0;
      calc_idx <= 0;
      result <= 0;
      done <= 0;
      ready <= 1;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = LOAD;
      end
      LOAD: begin
        if (done_in) next_state = PROCESS;
      end
      PROCESS: begin
        if (process_idx == 16) next_state = CALC_REMAINING;
      end
      CALC_REMAINING: begin
        if (calc_idx == stack_ptr) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Load buffer
  always @(posedge clk) begin
    if (!rst_n && state == LOAD && valid_in) begin
      buffer[buffer_idx] <= data_in[7:0];
      buffer_idx <= buffer_idx + 1;
    end
  end

  // Process stack
  always @(posedge clk) begin
    if (!rst_n && state == PROCESS) begin
      if (process_idx < 16) begin
        reg [7:0] current = buffer[process_idx];
        while (stack_ptr > 1 && stack[stack_ptr-1] <= min(current, stack[stack_ptr-2])) begin
          score <= score + min(current, stack[stack_ptr-2]);
          stack_ptr <= stack_ptr - 1;
        end
        stack[stack_ptr] <= current;
        stack_ptr <= stack_ptr + 1;
        process_idx <= process_idx + 1;
      end
    end
  end

  // Calculate remaining points
  always @(posedge clk) begin
    if (!rst_n && state == CALC_REMAINING) begin
      if (calc_idx < stack_ptr && calc_idx > 0 && calc_idx < stack_ptr - 1) begin
        score <= score + min(stack[calc_idx-1], stack[calc_idx+1]);
      end
      calc_idx <= calc_idx + 1;
    end
  end

  // Output result
  always @(posedge clk) begin
    if (!rst_n && state == DONE) begin
      result <= score;
      done <= 1;
      ready <= 0;
    end
  end

  // Ready signal
  always @(*) begin
    ready = (state == IDLE);
  end

endmodule