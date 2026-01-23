module count_upper (
  input clk,
  input rst_n,
  input start,
  input [5:0] str_len,
  input [127:0] str_data,
  output reg [3:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    CHECK_POS_0,
    CHECK_POS_2,
    CHECK_POS_4,
    CHECK_POS_6,
    CHECK_POS_8,
    CHECK_POS_10,
    CHECK_POS_12,
    CHECK_POS_14,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [3:0] count;
  reg [3:0] pos;

  // Uppercase vowels lookup table
  function automatic logic is_uppercase_vowel(input [7:0] c);
    return (c == 8'h41 || c == 8'h45 || c == 8'h49 || c == 8'h4F || c == 8'h55);
  endfunction

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      count <= 0;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
      if (current_state == DONE) begin
        result <= count;
        done <= 1;
      end else begin
        done <= 0;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = CHECK_POS_0;
      end
      CHECK_POS_0: next_state = CHECK_POS_2;
      CHECK_POS_2: next_state = CHECK_POS_4;
      CHECK_POS_4: next_state = CHECK_POS_6;
      CHECK_POS_6: next_state = CHECK_POS_8;
      CHECK_POS_8: next_state = CHECK_POS_10;
      CHECK_POS_10: next_state = CHECK_POS_12;
      CHECK_POS_12: next_state = CHECK_POS_14;
      CHECK_POS_14: next_state = DONE;
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Position tracking
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pos <= 0;
    end else begin
      case (current_state)
        IDLE: pos <= 0;
        CHECK_POS_0: pos <= 0;
        CHECK_POS_2: pos <= 2;
        CHECK_POS_4: pos <= 4;
        CHECK_POS_6: pos <= 6;
        CHECK_POS_8: pos <= 8;
        CHECK_POS_10: pos <= 10;
        CHECK_POS_12: pos <= 12;
        CHECK_POS_14: pos <= 14;
        DONE: pos <= 14;
      endcase
    end
  end

  // Count logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count <= 0;
    end else if (current_state != DONE && current_state != IDLE) begin
      if (pos < str_len) begin
        reg [7:0] char = str_data[(pos*8)+7:pos*8];
        if (is_uppercase_vowel(char)) begin
          count <= count + 1;
        end
      end
    end
  end

endmodule