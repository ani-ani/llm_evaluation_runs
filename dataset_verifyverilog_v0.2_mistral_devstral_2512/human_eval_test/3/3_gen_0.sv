module bank_account_checker (
  input clk,
  input rst_n,
  input start,
  input valid_in,
  input signed [15:0] operation,
  output reg balance_below_zero,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg signed [15:0] balance;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      balance <= 16'b0;
      balance_below_zero <= 1'b0;
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
        if (start) next_state = PROCESSING;
        else next_state = IDLE;
      end
      PROCESSING: begin
        if (!valid_in) next_state = DONE;
        else next_state = PROCESSING;
      end
      DONE: begin
        if (start) next_state = PROCESSING;
        else next_state = DONE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Balance update and below zero detection
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      balance <= 16'b0;
    end else if (current_state == PROCESSING && valid_in) begin
      balance <= balance + operation;
      if (balance < 16'sd0) balance_below_zero <= 1'b1;
    end
  end

  // Done signal
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
    end else if (current_state == PROCESSING && !valid_in) begin
      done <= 1'b1;
    end else if (current_state == DONE && start) begin
      done <= 1'b0;
    end
  end

endmodule