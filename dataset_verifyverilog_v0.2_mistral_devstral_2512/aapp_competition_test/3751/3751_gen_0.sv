module identifier_validator (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input valid_in,
  output reg result,
  output reg error,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    WAIT_START,
    VALIDATE,
    ERROR,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [7:0] next_expected;
  reg [7:0] last_char;
  reg [255:0] seen_chars;

  // Default assignments
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      next_expected <= 8'h61; // 'a'
      last_char <= 8'h00;
      seen_chars <= 256'h0;
      result <= 1'b0;
      error <= 1'b0;
      done <= 1'b0;
    end else begin
      current_state <= next_state;
    end
  end

  // State machine logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = WAIT_START;
          result = 1'b0;
          error = 1'b0;
          done = 1'b0;
          next_expected = 8'h61; // Reset to 'a'
          seen_chars = 256'h0;
        end
      end

      WAIT_START: begin
        if (valid_in) begin
          next_state = VALIDATE;
        end else if (!start) begin
          next_state = IDLE;
        end
      end

      VALIDATE: begin
        if (char_in == next_expected) begin
          // Correct next character
          seen_chars[char_in] = 1'b1;
          next_expected = char_in + 1'b1;
          result = 1'b1;
          error = 1'b0;
          next_state = WAIT_START;
        end else if (seen_chars[char_in]) begin
          // Duplicate character (allowed)
          result = 1'b1;
          error = 1'b0;
          next_state = WAIT_START;
        end else if (char_in < next_expected) begin
          // Character less than expected (allowed)
          seen_chars[char_in] = 1'b1;
          result = 1'b1;
          error = 1'b0;
          next_state = WAIT_START;
        end else begin
          // Character greater than expected (error)
          result = 1'b0;
          error = 1'b1;
          next_state = ERROR;
        end
      end

      ERROR: begin
        result = 1'b0;
        error = 1'b1;
        done = 1'b0;
      end

      DONE: begin
        result = 1'b1;
        error = 1'b0;
        done = 1'b1;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Handle end of stream
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
    end else if (current_state == WAIT_START && !valid_in && !start) begin
      // End of stream
      if (error) begin
        done <= 1'b0;
      end else begin
        done <= 1'b1;
      end
    end
  end

endmodule