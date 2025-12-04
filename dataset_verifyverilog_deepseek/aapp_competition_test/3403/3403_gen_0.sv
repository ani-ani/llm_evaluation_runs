module query_step_calculator(
  input clk,
  input rst_n,
  input start,
  input [63:0] query_word,
  output reg [6:0] step_count,
  output reg done
);

  localparam [7:0][63:0] DB = {
    64'h686F626F746E6963,
    64'h726F626F745F5F5F,
    64'h686F62695F5F5F5F,
    64'h686F6269745F5F5F,
    64'h726F62695F5F5F5F,
    64'h5F5F5F5F5F5F5F5F,
    64'h5F5F5F5F5F5F5F5F,
    64'h5F5F5F5F5F5F5F5F
  };

  typedef enum {
    IDLE,
    COMPARE_WORD,
    CHECK_CHAR,
    ACCUMULATE,
    DONE
  } state_t;

  reg [2:0] word_index;
  reg [2:0] char_index;
  state_t current_state;
  reg [63:0] current_db_word;
  reg exact_match;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      step_count <= 0;
      done <= 0;
      word_index <= 0;
      char_index <= 0;
      exact_match <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          done <= 0;
          if (start) begin
            current_state <= COMPARE_WORD;
            step_count <= 0;
            word_index <= 0;
            char_index <= 0;
            current_db_word <= DB[0];
          end
        end

        COMPARE_WORD: begin
          if (current_db_word == query_word) begin
            step_count <= step_count + 7'd1 + char_index;
            current_state <= DONE;
          end else begin
            char_index <= 0;
            current_state <= CHECK_CHAR;
          end
        end

        CHECK_CHAR: begin
          if (char_index < 7) begin
            if (current_db_word[char_index*8 +:8] == query_word[char_index*8 +:8]) begin
              char_index <= char_index + 1;
            end else begin
              current_state <= ACCUMULATE;
            end
          end else begin
            current_state <= ACCUMULATE;
          end
        end

        ACCUMULATE: begin
          step_count <= step_count + 7'd1 + char_index;
          if (word_index == 7) begin
            current_state <= DONE;
          end else begin
            word_index <= word_index + 1;
            current_db_word <= DB[word_index + 1];
            current_state <= COMPARE_WORD;
          end
        end

        DONE: begin
          done <= 1;
          current_state <= IDLE;
        end
      endcase
    end
  end
endmodule