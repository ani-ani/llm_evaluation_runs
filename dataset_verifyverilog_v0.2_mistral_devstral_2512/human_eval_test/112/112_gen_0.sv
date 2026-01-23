module reverse_delete (
  input clk,
  input rst_n,
  input start,
  input [7:0] s_char_0, s_char_1, s_char_2, s_char_3, s_char_4, s_char_5, s_char_6, s_char_7,
  input [7:0] c_char_0, c_char_1, c_char_2, c_char_3, c_char_4, c_char_5, c_char_6, c_char_7,
  input [3:0] s_len,
  input [3:0] c_len,
  output reg [7:0] result_char_0, result_char_1, result_char_2, result_char_3, result_char_4, result_char_5, result_char_6, result_char_7,
  output reg [3:0] result_len,
  output reg is_palindrome,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    CHECK_CHARS,
    BUILD_RESULT,
    CHECK_PALINDROME,
    DONE
  } state_t;

  state_t state, next_state;
  reg [7:0] s_chars [0:7];
  reg [7:0] c_chars [0:7];
  reg [7:0] result_chars [0:7];
  reg [7:0] match_flags [0:7];
  reg [3:0] counter;
  reg [3:0] result_counter;
  reg [3:0] palindrome_counter;
  reg [3:0] s_len_reg, c_len_reg;

  // Assign input arrays to registers for easier access
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s_chars[0] <= 8'h0;
      s_chars[1] <= 8'h0;
      s_chars[2] <= 8'h0;
      s_chars[3] <= 8'h0;
      s_chars[4] <= 8'h0;
      s_chars[5] <= 8'h0;
      s_chars[6] <= 8'h0;
      s_chars[7] <= 8'h0;
      c_chars[0] <= 8'h0;
      c_chars[1] <= 8'h0;
      c_chars[2] <= 8'h0;
      c_chars[3] <= 8'h0;
      c_chars[4] <= 8'h0;
      c_chars[5] <= 8'h0;
      c_chars[6] <= 8'h0;
      c_chars[7] <= 8'h0;
    end else begin
      s_chars[0] <= s_char_0;
      s_chars[1] <= s_char_1;
      s_chars[2] <= s_char_2;
      s_chars[3] <= s_char_3;
      s_chars[4] <= s_char_4;
      s_chars[5] <= s_char_5;
      s_chars[6] <= s_char_6;
      s_chars[7] <= s_char_7;
      c_chars[0] <= c_char_0;
      c_chars[1] <= c_char_1;
      c_chars[2] <= c_char_2;
      c_chars[3] <= c_char_3;
      c_chars[4] <= c_char_4;
      c_chars[5] <= c_char_5;
      c_chars[6] <= c_char_6;
      c_chars[7] <= c_char_7;
    end
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      counter <= 4'd0;
      result_counter <= 4'd0;
      palindrome_counter <= 4'd0;
      s_len_reg <= 4'd0;
      c_len_reg <= 4'd0;
      done <= 1'b0;
      is_palindrome <= 1'b0;
      result_len <= 4'd0;
      result_char_0 <= 8'h0;
      result_char_1 <= 8'h0;
      result_char_2 <= 8'h0;
      result_char_3 <= 8'h0;
      result_char_4 <= 8'h0;
      result_char_5 <= 8'h0;
      result_char_6 <= 8'h0;
      result_char_7 <= 8'h0;
    end else begin
      state <= next_state;
      if (state == CHECK_CHARS) begin
        counter <= counter + 1'b1;
      end else if (state == BUILD_RESULT) begin
        result_counter <= result_counter + 1'b1;
      end else if (state == CHECK_PALINDROME) begin
        palindrome_counter <= palindrome_counter + 1'b1;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = CHECK_CHARS;
          s_len_reg = s_len;
          c_len_reg = c_len;
          counter = 4'd0;
          result_counter = 4'd0;
          palindrome_counter = 4'd0;
          is_palindrome = 1'b0;
          result_len = 4'd0;
          done = 1'b0;
        end
      end
      CHECK_CHARS: begin
        if (counter == s_len_reg - 1) begin
          next_state = BUILD_RESULT;
        end
      end
      BUILD_RESULT: begin
        if (result_counter == s_len_reg) begin
          next_state = CHECK_PALINDROME;
        end
      end
      CHECK_PALINDROME: begin
        if (palindrome_counter == (result_len + 1'b1) / 2) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
      default: next_state = IDLE;
    endcase
  end

  // CHECK_CHARS state logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      match_flags[0] <= 1'b0;
      match_flags[1] <= 1'b0;
      match_flags[2] <= 1'b0;
      match_flags[3] <= 1'b0;
      match_flags[4] <= 1'b0;
      match_flags[5] <= 1'b0;
      match_flags[6] <= 1'b0;
      match_flags[7] <= 1'b0;
    end else if (state == CHECK_CHARS) begin
      reg [7:0] current_char = s_chars[counter];
      reg match = 1'b0;
      for (int i = 0; i < c_len_reg; i = i + 1) begin
        if (current_char == c_chars[i]) begin
          match = 1'b1;
        end
      end
      match_flags[counter] <= match;
    end
  end

  // BUILD_RESULT state logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_chars[0] <= 8'h0;
      result_chars[1] <= 8'h0;
      result_chars[2] <= 8'h0;
      result_chars[3] <= 8'h0;
      result_chars[4] <= 8'h0;
      result_chars[5] <= 8'h0;
      result_chars[6] <= 8'h0;
      result_chars[7] <= 8'h0;
    end else if (state == BUILD_RESULT) begin
      if (!match_flags[result_counter]) begin
        result_chars[result_len] <= s_chars[result_counter];
        result_len <= result_len + 1'b1;
      end
    end
  end

  // CHECK_PALINDROME state logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      is_palindrome <= 1'b0;
    end else if (state == CHECK_PALINDROME) begin
      if (result_len == 4'd0 || result_len == 4'd1) begin
        is_palindrome <= 1'b1;
      end else begin
        reg [7:0] left_char = result_chars[palindrome_counter];
        reg [7:0] right_char = result_chars[result_len - 1'b1 - palindrome_counter];
        if (left_char != right_char) begin
          is_palindrome <= 1'b0;
        end else if (palindrome_counter == (result_len + 1'b1) / 2 - 1'b1) begin
          is_palindrome <= 1'b1;
        end
      end
    end
  end

  // Output assignments
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_char_0 <= 8'h0;
      result_char_1 <= 8'h0;
      result_char_2 <= 8'h0;
      result_char_3 <= 8'h0;
      result_char_4 <= 8'h0;
      result_char_5 <= 8'h0;
      result_char_6 <= 8'h0;
      result_char_7 <= 8'h0;
      done <= 1'b0;
    end else if (state == DONE) begin
      result_char_0 <= result_chars[0];
      result_char_1 <= result_chars[1];
      result_char_2 <= result_chars[2];
      result_char_3 <= result_chars[3];
      result_char_4 <= result_chars[4];
      result_char_5 <= result_chars[5];
      result_char_6 <= result_chars[6];
      result_char_7 <= result_chars[7];
      done <= 1'b1;
    end else begin
      result_char_0 <= 8'h0;
      result_char_1 <= 8'h0;
      result_char_2 <= 8'h0;
      result_char_3 <= 8'h0;
      result_char_4 <= 8'h0;
      result_char_5 <= 8'h0;
      result_char_6 <= 8'h0;
      result_char_7 <= 8'h0;
      done <= 1'b0;
    end
  end

endmodule