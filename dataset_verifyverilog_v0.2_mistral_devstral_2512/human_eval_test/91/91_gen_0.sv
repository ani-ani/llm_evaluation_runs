module boredom_counter(
  input clk,
  input rst_n,
  input start,
  input [7:0] char_data,
  input [3:0] char_index,
  input char_valid,
  output reg [3:0] boredom_count,
  output reg done,
  output reg error
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    WAITING_SENTENCE_START,
    IN_SENTENCE,
    CHECKING_START,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [3:0] count_reg;
  reg [3:0] index_reg;
  reg sentence_start_flag;
  reg delimiter_flag;

  // Delimiter check
  function logic is_delimiter(input [7:0] c);
    return (c == 8'h2E) || (c == 8'h3F) || (c == 8'h21);
  endfunction

  // Space check
  function logic is_space(input [7:0] c);
    return (c == 8'h20);
  endfunction

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      count_reg <= 4'd0;
      index_reg <= 4'd0;
      sentence_start_flag <= 1'b0;
      delimiter_flag <= 1'b0;
      boredom_count <= 4'd0;
      done <= 1'b0;
      error <= 1'b0;
    end else begin
      current_state <= next_state;
      if (next_state == DONE) begin
        count_reg <= count_reg; // Hold value
      end else if (char_valid && (current_state != IDLE) && (current_state != DONE)) begin
        index_reg <= char_index;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = WAITING_SENTENCE_START;
          count_reg = 4'd0;
          index_reg = 4'd0;
          sentence_start_flag = 1'b1; // First character is sentence start
          delimiter_flag = 1'b0;
        end
      end

      WAITING_SENTENCE_START: begin
        if (char_valid) begin
          if (is_space(char_data)) begin
            // Stay in WAITING_SENTENCE_START
          end else if (is_delimiter(char_data)) begin
            delimiter_flag = 1'b1;
            // Stay in WAITING_SENTENCE_START
          end else begin
            // Found non-space, non-delimiter character
            if (char_data == 8'h49) begin
              count_reg = count_reg + 1;
            end
            next_state = IN_SENTENCE;
            sentence_start_flag = 1'b0;
            delimiter_flag = 1'b0;
          end
        end
        
        if (char_index == 4'd15) begin
          next_state = DONE;
        end
      end

      IN_SENTENCE: begin
        if (char_valid) begin
          if (is_delimiter(char_data)) begin
            delimiter_flag = 1'b1;
            next_state = WAITING_SENTENCE_START;
            sentence_start_flag = 1'b1;
          end else if (is_space(char_data)) begin
            // Stay in IN_SENTENCE
          end else begin
            // Stay in IN_SENTENCE
          end
        end
        
        if (char_index == 4'd15) begin
          next_state = DONE;
        end
      end

      CHECKING_START: begin
        if (char_valid) begin
          if (char_data == 8'h49) begin
            count_reg = count_reg + 1;
          end
          next_state = IN_SENTENCE;
          sentence_start_flag = 1'b0;
        end
        
        if (char_index == 4'd15) begin
          next_state = DONE;
        end
      end

      DONE: begin
        // Stay in DONE until reset
      end

      default: next_state = IDLE;
    endcase
  end

  // Output assignments
  always @(*) begin
    boredom_count = count_reg;
    done = (current_state == DONE);
    error = (char_index > 4'd15) || (char_index < 4'd0 && current_state != IDLE);
  end

endmodule