module bracket_fix_checker (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input valid_in,
  output reg result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t state, next_state;

  // Counters and registers
  reg signed [3:0] balance;          // Current balance (-8 to +7)
  reg signed [3:0] min_balance;     // Minimum balance encountered
  reg [2:0] char_count;             // Character counter (0-7)

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      balance <= 0;
      min_balance <= 0;
      char_count <= 0;
      result <= 0;
      done <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state and processing logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = PROCESSING;
          balance = 0;
          min_balance = 0;
          char_count = 0;
          result = 0;
          done = 0;
        end
      end

      PROCESSING: begin
        if (valid_in) begin
          // Process character
          if (char_in == 8'h28) begin
            balance = balance + 1;
          end else if (char_in == 8'h29) begin
            balance = balance - 1;
            if (balance < min_balance) begin
              min_balance = balance;
            end
          end

          // Increment character counter
          char_count = char_count + 1;

          // Check if done processing
          if (char_count == 7) begin
            next_state = DONE;
            // Final evaluation
            if (balance == 0 && min_balance >= -1) begin
              result = 1;
            end else begin
              result = 0;
            end
            done = 1;
          end
        end
      end

      DONE: begin
        if (!start) begin
          next_state = IDLE;
          done = 0;
        end
      end
    endcase
  end

endmodule