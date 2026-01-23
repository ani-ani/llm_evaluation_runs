module words_string_splitter (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input valid_in,
  output reg [7:0] words [0:7][0:7],
  output reg [2:0] word_count,
  output reg done,
  output reg error
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    SKIP_DELIM,
    READ_WORD,
    CHECK_DELIM,
    DONE,
    ERROR
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [2:0] current_word_idx;  // Index of current word (0-7)
  reg [2:0] current_char_idx;  // Index of current character in word (0-7)
  reg [7:0] current_word [0:7]; // Temporary storage for current word

  // Initialize outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      word_count <= 0;
      done <= 0;
      error <= 0;
      current_word_idx <= 0;
      current_char_idx <= 0;
      for (int i = 0; i < 8; i++) begin
        for (int j = 0; j < 8; j++) begin
          words[i][j] <= 0;
        end
      end
    end else begin
      current_state <= next_state;
    end
  end

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      next_state <= IDLE;
    end else begin
      case (current_state)
        IDLE: begin
          if (start) begin
            next_state <= SKIP_DELIM;
          end else begin
            next_state <= IDLE;
          end
        end

        SKIP_DELIM: begin
          if (valid_in) begin
            if (char_in == " " || char_in == ",") begin
              next_state <= SKIP_DELIM;
            end else begin
              next_state <= READ_WORD;
            end
          end else begin
            next_state <= SKIP_DELIM;
          end
        end

        READ_WORD: begin
          if (valid_in) begin
            if (char_in == " " || char_in == ",") begin
              next_state <= CHECK_DELIM;
            end else begin
              if (current_char_idx == 7) begin
                next_state <= ERROR;
              end else begin
                next_state <= READ_WORD;
              end
            end
          end else begin
            next_state <= READ_WORD;
          end
        end

        CHECK_DELIM: begin
          if (valid_in) begin
            if (char_in == " " || char_in == ",") begin
              next_state <= SKIP_DELIM;
            end else begin
              if (current_word_idx == 7) begin
                next_state <= ERROR;
              end else begin
                next_state <= READ_WORD;
              end
            end
          end else begin
            next_state <= CHECK_DELIM;
          end
        end

        DONE: begin
          next_state <= IDLE;
        end

        ERROR: begin
          next_state <= IDLE;
        end

        default: begin
          next_state <= IDLE;
        end
      endcase
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      error <= 0;
    end else begin
      case (current_state)
        DONE: begin
          done <= 1;
          error <= 0;
        end

        ERROR: begin
          done <= 0;
          error <= 1;
        end

        default: begin
          done <= 0;
          error <= 0;
        end
      endcase
    end
  end

  // Word storage logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_word_idx <= 0;
      current_char_idx <= 0;
      for (int i = 0; i < 8; i++) begin
        current_word[i] <= 0;
      end
    end else begin
      case (current_state)
        READ_WORD: begin
          if (valid_in && char_in != " " && char_in != ",") begin
            current_word[current_char_idx] <= char_in;
            current_char_idx <= current_char_idx + 1;
          end
        end

        CHECK_DELIM: begin
          if (valid_in && (char_in == " " || char_in == ",")) begin
            // Store the current word
            for (int i = 0; i < 8; i++) begin
              words[current_word_idx][i] <= current_word[i];
            end
            current_word_idx <= current_word_idx + 1;
            current_char_idx <= 0;
          end else if (valid_in) begin
            // New word starts
            current_word[0] <= char_in;
            current_char_idx <= 1;
          end
        end

        SKIP_DELIM: begin
          if (valid_in && char_in != " " && char_in != ",") begin
            current_word[0] <= char_in;
            current_char_idx <= 1;
          end
        end

        DONE: begin
          word_count <= current_word_idx;
        end

        ERROR: begin
          word_count <= 0;
        end

        default: begin
          // No action
        end
      endcase
    end
  end

  // Completion detection
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset handled elsewhere
    end else begin
      if (current_state == CHECK_DELIM && !valid_in) begin
        // Store the last word
        for (int i = 0; i < 8; i++) begin
          words[current_word_idx][i] <= current_word[i];
        end
        current_word_idx <= current_word_idx + 1;
        next_state <= DONE;
      end
    end
  end

endmodule