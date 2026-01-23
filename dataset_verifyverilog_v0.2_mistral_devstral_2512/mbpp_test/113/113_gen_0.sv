module check_integer (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input [2:0] char_idx,
  input valid_char,
  output reg result,
  output reg done,
  output reg error
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CHECK_FIRST,
    CHECK_REMAINING,
    VALID,
    INVALID,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [2:0] char_counter;
  reg first_char_valid;
  reg all_digits_valid;
  reg has_non_null;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      char_counter <= 0;
      first_char_valid <= 0;
      all_digits_valid <= 0;
      has_non_null <= 0;
      result <= 0;
      done <= 0;
      error <= 0;
    end else begin
      current_state <= next_state;
      if (next_state == CHECK_FIRST || next_state == CHECK_REMAINING) begin
        if (char_counter < 7) char_counter <= char_counter + 1;
        else char_counter <= 0;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = CHECK_FIRST;
      end
      CHECK_FIRST: begin
        if (valid_char) begin
          if (char_in == 8'b0) begin
            next_state = INVALID;
          end else if ((char_in >= 8'h30 && char_in <= 8'h39) || char_in == 8'h2B || char_in == 8'h2D) begin
            first_char_valid = 1;
            has_non_null = 1;
            if (char_counter == 7) next_state = VALID;
            else next_state = CHECK_REMAINING;
          end else begin
            next_state = INVALID;
          end
        end
      end
      CHECK_REMAINING: begin
        if (valid_char) begin
          if (char_in == 8'b0) begin
            // Null character - continue checking
            if (char_counter == 7) next_state = VALID;
          end else if (char_in >= 8'h30 && char_in <= 8'h39) begin
            has_non_null = 1;
            if (char_counter == 7) next_state = VALID;
          end else begin
            next_state = INVALID;
          end
        end
      end
      VALID: begin
        next_state = DONE;
      end
      INVALID: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Output logic
  always @(*) begin
    result = 0;
    done = 0;
    error = 0;
    case (current_state)
      VALID: begin
        result = 1;
        done = 1;
        error = 0;
      end
      INVALID: begin
        result = 0;
        done = 1;
        error = 1;
      end
      DONE: begin
        if (current_state == VALID) begin
          result = 1;
          done = 1;
          error = 0;
        end else if (current_state == INVALID) begin
          result = 0;
          done = 1;
          error = 1;
        end
      end
    endcase
  end

  // Edge case handling for empty string
  always @(posedge clk) begin
    if (current_state == DONE && !has_non_null) begin
      error <= 1;
      result <= 0;
      done <= 1;
    end
  end

endmodule