module wire_untangle (
  input clk,
  input rst_n,
  input start,
  input [5:0] char_in,
  input valid_in,
  input end_in,
  output reg result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    RECV,
    PROCESS,
    COMPLETE
  } state_t;

  // Stack and pointer
  reg [5:0] stack [0:31];
  reg [4:0] sp = 0;

  // State register
  state_t current_state, next_state;

  // Character comparison
  wire char_match = (sp > 0) && (stack[sp-1] == char_in);

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      sp <= 0;
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
        if (start) next_state = RECV;
      end
      RECV: begin
        if (end_in) next_state = PROCESS;
      end
      PROCESS: begin
        next_state = COMPLETE;
      end
      COMPLETE: begin
        if (start) next_state = RECV;
      end
    endcase
  end

  // Stack operations
  always @(posedge clk) begin
    if (!rst_n) begin
      sp <= 0;
    end else if (current_state == RECV && valid_in) begin
      if (char_match) begin
        sp <= sp - 1;
      end else if (sp < 32) begin
        stack[sp] <= char_in;
        sp <= sp + 1;
      end
    end
  end

  // Result and done logic
  always @(posedge clk) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else if (current_state == PROCESS) begin
      result <= (sp == 0);
      done <= 1;
    end else if (current_state == COMPLETE && start) begin
      done <= 0;
    end
  end

endmodule