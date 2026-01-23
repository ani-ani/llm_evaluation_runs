module next_smallest_palindrome (
  input clk,
  input rst_n,
  input start,
  input [15:0] num_in,
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    INCREMENT,
    EXTRACT_DIGITS,
    CHECK_PALINDROME,
    VERIFY,
    DONE
  } state_t;

  state_t state, next_state;
  reg [15:0] candidate;
  reg [4:0] digit_count;
  reg [3:0] digit [0:4]; // Max 5 digits (0-4)
  reg [3:0] digit_ptr;
  reg [3:0] compare_ptr;
  reg [5:0] iteration_count;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      candidate <= 0;
      digit_count <= 0;
      digit_ptr <= 0;
      compare_ptr <= 0;
      iteration_count <= 0;
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
        if (start) begin
          next_state = INCREMENT;
          candidate = num_in;
          iteration_count = 0;
        end
      end
      INCREMENT: begin
        next_state = EXTRACT_DIGITS;
        candidate = candidate + 1;
        iteration_count = iteration_count + 1;
      end
      EXTRACT_DIGITS: begin
        next_state = CHECK_PALINDROME;
      end
      CHECK_PALINDROME: begin
        if (digit_ptr == digit_count) begin
          next_state = VERIFY;
        end
      end
      VERIFY: begin
        if (compare_ptr == (digit_count + 1) / 2) begin
          next_state = DONE;
        end else begin
          next_state = INCREMENT;
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end

  // Digit extraction logic
  always @(posedge clk) begin
    if (!rst_n && state == EXTRACT_DIGITS) begin
      reg [15:0] temp = candidate;
      digit_count = 0;
      digit_ptr = 0;
      // Extract digits
      while (temp > 0 && digit_count < 5) begin
        digit[digit_count] = temp % 10;
        temp = temp / 10;
        digit_count = digit_count + 1;
      end
      // If number is 0, set digit_count to 1
      if (candidate == 0) begin
        digit[0] = 0;
        digit_count = 1;
      end
      compare_ptr = 0;
    end
  end

  // Palindrome check logic
  always @(posedge clk) begin
    if (!rst_n && state == CHECK_PALINDROME) begin
      if (digit[digit_ptr] == digit[digit_count - 1 - digit_ptr]) begin
        digit_ptr = digit_ptr + 1;
      end else begin
        digit_ptr = digit_count; // Force completion
      end
    end
  end

  // Verification logic
  always @(posedge clk) begin
    if (!rst_n && state == VERIFY) begin
      if (digit[compare_ptr] == digit[digit_count - 1 - compare_ptr]) begin
        compare_ptr = compare_ptr + 1;
      end else begin
        compare_ptr = (digit_count + 1) / 2; // Force completion
      end
    end
  end

  // Output logic
  always @(posedge clk) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else begin
      if (state == DONE) begin
        result <= candidate;
        done <= 1;
      end else begin
        done <= 0;
      end
    end
  end

  // Safety check for max iterations
  always @(posedge clk) begin
    if (!rst_n && iteration_count == 64) begin
      state <= DONE;
      result <= 0; // Wrap to 0 as per edge case
      done <= 1;
    end
  end

endmodule