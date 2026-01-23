module adverb_detector (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input [3:0] char_valid,
  output reg [3:0] start_pos,
  output reg [3:0] end_pos,
  output reg [39:0] word_out,
  output reg found,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    SEARCH,
    MATCH,
    FOUND,
    DONE
  } state_t;

  state_t state = IDLE;
  reg [3:0] char_count = 0;
  reg [3:0] word_start = 0;
  reg [39:0] word_buffer = 0;
  reg [3:0] word_length = 0;
  reg [7:0] prev_char = 0;
  reg [7:0] prev_prev_char = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      char_count <= 0;
      word_start <= 0;
      word_buffer <= 0;
      word_length <= 0;
      prev_char <= 0;
      prev_prev_char <= 0;
      start_pos <= 0;
      end_pos <= 0;
      word_out <= 0;
      found <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SEARCH;
            char_count <= 0;
            word_start <= 0;
            word_buffer <= 0;
            word_length <= 0;
            prev_char <= 0;
            prev_prev_char <= 0;
            start_pos <= 0;
            end_pos <= 0;
            word_out <= 0;
            found <= 0;
            done <= 0;
          end
        end

        SEARCH: begin
          if (char_valid) begin
            char_count <= char_count + 1;
            if (char_in != 8'h20) begin
              state <= MATCH;
              word_start <= char_count;
              word_buffer[7:0] <= char_in;
              word_length <= 1;
              prev_prev_char <= prev_char;
              prev_char <= char_in;
            end
          end
          if (char_count == 15) begin
            state <= DONE;
            done <= 1;
          end
        end

        MATCH: begin
          if (char_valid) begin
            char_count <= char_count + 1;
            if (char_in == 8'h20 || char_count == 15) begin
              if (prev_char == 8'h79 && prev_prev_char == 8'h6C) begin
                state <= FOUND;
                end_pos <= char_count - 1;
                start_pos <= word_start;
                word_out <= word_buffer;
                found <= 1;
              end else begin
                state <= SEARCH;
              end
            end else begin
              if (word_length < 5) begin
                word_buffer[(word_length + 1) * 8 - 1: word_length * 8] <= char_in;
                word_length <= word_length + 1;
              end
              prev_prev_char <= prev_char;
              prev_char <= char_in;
            end
          end
          if (char_count == 15) begin
            state <= DONE;
            done <= 1;
          end
        end

        FOUND: begin
          state <= DONE;
          done <= 1;
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule