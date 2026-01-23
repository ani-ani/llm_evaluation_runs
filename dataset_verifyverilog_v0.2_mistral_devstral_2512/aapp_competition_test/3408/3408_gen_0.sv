module pattern_matcher (
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] word_char,
  input [7:0][7:0] pattern_char,
  input [3:0] pattern_len,
  input [3:0] word_len,
  output reg match,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    FIND_STAR,
    CHECK_PREFIX,
    CHECK_SUFFIX,
    MATCH_DONE,
    NO_MATCH
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [2:0] star_pos;
  reg [2:0] prefix_len;
  reg [2:0] suffix_len;
  reg [2:0] prefix_idx;
  reg [2:0] suffix_idx;
  reg prefix_match;
  reg suffix_match;
  reg [2:0] counter;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      match <= 0;
      done <= 0;
      star_pos <= 0;
      prefix_len <= 0;
      suffix_len <= 0;
      prefix_idx <= 0;
      suffix_idx <= 0;
      prefix_match <= 0;
      suffix_match <= 0;
      counter <= 0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          match <= 0;
          done <= 0;
        end

        FIND_STAR: begin
          if (counter < 8) begin
            if (pattern_char[counter] == 8'h2A) begin
              star_pos <= counter;
            end
            counter <= counter + 1;
          end
        end

        CHECK_PREFIX: begin
          if (prefix_idx < star_pos) begin
            if (word_char[prefix_idx] != pattern_char[prefix_idx]) begin
              prefix_match <= 0;
            end else begin
              prefix_match <= 1;
              prefix_idx <= prefix_idx + 1;
            end
          end
        end

        CHECK_SUFFIX: begin
          if (suffix_idx < suffix_len) begin
            if (word_char[word_len - suffix_len + suffix_idx] != pattern_char[star_pos + 1 + suffix_idx]) begin
              suffix_match <= 0;
            end else begin
              suffix_match <= 1;
              suffix_idx <= suffix_idx + 1;
            end
          end
        end

        MATCH_DONE: begin
          match <= 1;
          done <= 1;
        end

        NO_MATCH: begin
          match <= 0;
          done <= 1;
        end

        default: begin
          current_state <= IDLE;
          match <= 0;
          done <= 0;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = FIND_STAR;
          counter = 0;
          star_pos = 0;
          prefix_len = 0;
          suffix_len = 0;
          prefix_idx = 0;
          suffix_idx = 0;
          prefix_match = 1;
          suffix_match = 1;
        end
      end

      FIND_STAR: begin
        if (counter == 8) begin
          if (star_pos == 0) begin
            next_state = NO_MATCH;
          end else begin
            prefix_len = star_pos;
            suffix_len = pattern_len - star_pos - 1;
            if (word_len < pattern_len - 1) begin
              next_state = NO_MATCH;
            end else begin
              next_state = CHECK_PREFIX;
              prefix_idx = 0;
            end
          end
        end
      end

      CHECK_PREFIX: begin
        if (prefix_idx == star_pos) begin
          if (prefix_match) begin
            next_state = CHECK_SUFFIX;
            suffix_idx = 0;
          end else begin
            next_state = NO_MATCH;
          end
        end
      end

      CHECK_SUFFIX: begin
        if (suffix_idx == suffix_len) begin
          if (suffix_match) begin
            next_state = MATCH_DONE;
          end else begin
            next_state = NO_MATCH;
          end
        end
      end

      MATCH_DONE, NO_MATCH: begin
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule