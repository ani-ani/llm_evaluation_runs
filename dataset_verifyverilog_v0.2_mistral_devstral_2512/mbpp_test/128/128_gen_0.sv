module long_words_filter (
  input clk,
  input rst_n,
  input start,
  input [7:0] threshold,
  input [63:0] input_string,
  output reg [63:0] result_word,
  output reg done,
  output reg found
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SCAN,
    COUNT_CHECK,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [63:0] current_word;
  reg [2:0] word_length;
  reg [2:0] char_index;
  reg [7:0] current_char;
  reg [2:0] word_start_index;
  reg word_found;

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result_word <= 64'b0;
      done <= 1'b0;
      found <= 1'b0;
      current_word <= 64'b0;
      word_length <= 3'b0;
      char_index <= 3'b0;
      current_char <= 8'b0;
      word_start_index <= 3'b0;
      word_found <= 1'b0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          if (start) begin
            next_state <= SCAN;
            char_index <= 3'b0;
            word_length <= 3'b0;
            word_start_index <= 3'b0;
            word_found <= 1'b0;
            found <= 1'b0;
            done <= 1'b0;
          end
        end

        SCAN: begin
          current_char <= input_string[(char_index + 1) * 8 - 1 : char_index * 8];

          if (current_char == 8'h20 || char_index == 7) begin
            // Space or end of string
            if (current_char != 8'h20) begin
              word_length <= word_length + 1;
            end
            next_state <= COUNT_CHECK;
          end else begin
            if (word_length == 0) begin
              word_start_index <= char_index;
            end
            word_length <= word_length + 1;
            char_index <= char_index + 1;
          end
        end

        COUNT_CHECK: begin
          if (word_length > threshold && !word_found) begin
            // Extract the word
            for (int i = 0; i < 8; i = i + 1) begin
              if (i < word_length) begin
                result_word[(i + 1) * 8 - 1 : i * 8] <= input_string[(word_start_index + i + 1) * 8 - 1 : (word_start_index + i) * 8];
              end else begin
                result_word[(i + 1) * 8 - 1 : i * 8] <= 8'b0;
              end
            end
            word_found <= 1'b1;
            found <= 1'b1;
          end

          if (char_index == 7) begin
            next_state <= DONE;
          end else begin
            next_state <= SCAN;
            char_index <= char_index + 1;
            word_length <= 3'b0;
          end
        end

        DONE: begin
          done <= 1'b1;
          next_state <= IDLE;
        end

        default: begin
          next_state <= IDLE;
        end
      endcase
    end
  end

  // Default state transitions
  always @(*) begin
    next_state = current_state;
  end

endmodule