module reverse_words (
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] string_data,
  input [2:0] string_length,
  output reg [7:0][7:0] result_data,
  output reg [2:0] result_length,
  output reg done
);

  // Define states
  typedef enum logic [1:0] {
    IDLE,
    SCAN_WORDS,
    BUILD_RESULT,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Word buffer (max 4 words, each with start and length)
  typedef struct {
    logic [2:0] start_pos;
    logic [2:0] length;
  } word_info_t;

  word_info_t word_buffer [0:3];
  logic [1:0] word_count;

  // Internal counters
  logic [2:0] scan_pos;
  logic [2:0] build_pos;
  logic [2:0] word_idx;
  logic [2:0] char_idx;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      word_count <= 0;
      scan_pos <= 0;
      build_pos <= 0;
      word_idx <= 0;
      char_idx <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = SCAN_WORDS;
      end
      SCAN_WORDS: begin
        if (scan_pos == string_length) next_state = BUILD_RESULT;
      end
      BUILD_RESULT: begin
        if (build_pos == string_length) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Scan words state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      scan_pos <= 0;
      word_count <= 0;
    end else if (current_state == SCAN_WORDS) begin
      if (scan_pos < string_length) begin
        if (string_data[scan_pos] == 8'h20) begin
          // Space found, end of current word
          word_buffer[word_count].length = scan_pos - word_buffer[word_count].start_pos;
          word_count <= word_count + 1;
        end else if (scan_pos == 0 || string_data[scan_pos-1] == 8'h20) begin
          // Start of new word
          word_buffer[word_count].start_pos = scan_pos;
        end
        scan_pos <= scan_pos + 1;
      end
    end
  end

  // Build result state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      build_pos <= 0;
      word_idx <= 0;
      char_idx <= 0;
    end else if (current_state == BUILD_RESULT) begin
      if (build_pos < string_length) begin
        if (word_idx < word_count) begin
          if (char_idx < word_buffer[word_idx].length) begin
            result_data[build_pos] = string_data[word_buffer[word_idx].start_pos + char_idx];
            char_idx <= char_idx + 1;
          end else begin
            // Add space if not last word
            if (word_idx < word_count - 1) begin
              result_data[build_pos] = 8'h20;
            end
            word_idx <= word_idx + 1;
            char_idx <= 0;
          end
        end
        build_pos <= build_pos + 1;
      end
    end
  end

  // Output handling
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_length <= 0;
      done <= 1'b0;
    end else begin
      if (current_state == DONE) begin
        result_length <= string_length;
        done <= 1'b1;
      end else begin
        done <= 1'b0;
      end
    end
  end

endmodule