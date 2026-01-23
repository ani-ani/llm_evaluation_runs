module correct_bracketing (
  input clk,
  input rst_n,
  input start,
  input [127:0] brackets,
  output reg result,
  output reg done
);

  // Define states
  typedef enum logic [1:0] {
    IDLE,
    CHECK_CHAR,
    VALIDATE,
    DONE
  } state_t;

  // State register
  state_t state, next_state;

  // Counter for balance
  reg signed [4:0] balance;

  // Character index counter
  reg [3:0] char_idx;

  // Character being processed
  reg [7:0] current_char;

  // Reset logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      balance <= 0;
      char_idx <= 0;
      result <= 0;
      done <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CHECK_CHAR;
      end
      CHECK_CHAR: begin
        if (char_idx == 15) next_state = VALIDATE;
      end
      VALIDATE: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Character processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      char_idx <= 0;
      balance <= 0;
    end else if (state == CHECK_CHAR) begin
      current_char = brackets[(char_idx + 1) * 8 - 1 : char_idx * 8];
      
      // Process character
      if (current_char == 8'h28) begin  // '('
        balance <= balance + 1;
      end else if (current_char == 8'h29) begin  // ')'
        balance <= balance - 1;
      end
      
      // Check for negative balance
      if (balance < 0) begin
        result <= 0;
      end
      
      // Increment character index
      char_idx <= char_idx + 1;
    end
  end

  // Validation logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else if (state == VALIDATE) begin
      result <= (balance == 0) ? 1 : 0;
    end else if (state == DONE) begin
      done <= 1;
    end else if (state == IDLE) begin
      done <= 0;
    end
  end

endmodule