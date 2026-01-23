module adverb_finder (
  input clk,
  input rst_n,
  input start,
  input [127:0] text,
  output reg [3:0] start_pos,
  output reg [3:0] end_pos,
  output reg found,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    SCAN,
    CHECK_LY,
    VERIFY,
    DONE
  } state_t;

  state_t state, next_state;
  reg [3:0] current_pos;
  reg [3:0] word_start;
  reg [7:0] current_char, next_char;
  reg is_word_char;
  reg [3:0] ly_pos;

  // Character processing
  function logic is_alphabetic(input [7:0] c);
    return (c >= 8'h41 && c <= 8'h5A) || (c >= 8'h61 && c <= 8'h7A);
  endfunction

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_pos <= 0;
      word_start <= 0;
      start_pos <= 0;
      end_pos <= 0;
      found <= 0;
      done <= 0;
    end else begin
      state <= next_state;
      
      if (state == SCAN || state == CHECK_LY || state == VERIFY) begin
        current_pos <= current_pos + 1;
      end
      
      if (state == IDLE && start) begin
        current_pos <= 0;
        word_start <= 0;
        found <= 0;
        done <= 0;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = SCAN;
      end
      
      SCAN: begin
        current_char = text[(current_pos+1)*8-1 : current_pos*8];
        is_word_char = is_alphabetic(current_char);
        
        if (is_word_char) begin
          if (current_pos == word_start) begin
            word_start = current_pos;
          end
        end else begin
          word_start = current_pos + 1;
        end
        
        if (current_char == 8'h6C && is_word_char) begin // 'l' found
          next_state = CHECK_LY;
          ly_pos = current_pos;
        end else if (current_pos == 15) begin
          next_state = DONE;
        end
      end
      
      CHECK_LY: begin
        next_char = text[(current_pos+1)*8-1 : current_pos*8];
        if (next_char == 8'h79) begin // 'y' found
          next_state = VERIFY;
        end else begin
          next_state = SCAN;
        end
      end
      
      VERIFY: begin
        start_pos = word_start;
        end_pos = current_pos;
        found = 1;
        next_state = DONE;
      end
      
      DONE: begin
        done = 1;
        if (!start) begin
          next_state = IDLE;
          done = 0;
        end
      end
    endcase
  end

endmodule