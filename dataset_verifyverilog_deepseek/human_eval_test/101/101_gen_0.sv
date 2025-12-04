module word_splitter (
  input clk,
  input rst_n,
  input start,
  input [127:0] ascii_str,
  output reg [511:0] words,
  output reg [3:0] word_count,
  output reg done
);

  enum {IDLE, PROCESSING, DONE} state_reg;
  reg [3:0] current_char_index;
  reg [511:0] temp_words;
  reg [3:0] word_count_reg;
  reg in_word_reg;
  reg [4:0] current_char_pos_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state_reg <= IDLE;
      current_char_index <= 4'b0;
      temp_words <= 512'b0;
      word_count_reg <= 4'b0;
      in_word_reg <= 0;
      current_char_pos_reg <= 0;
      words <= 512'b0;
      word_count <= 4'b0;
      done <= 0;
    end else begin
      case (state_reg)
        IDLE: begin
          done <= 0;
          if (start) begin
            state_reg <= PROCESSING;
            current_char_index <= 0;
            temp_words <= 512'b0;
            word_count_reg <= 0;
            in_word_reg <= 0;
            current_char_pos_reg <= 0;
          end
        end

        PROCESSING: begin
          if (current_char_index < 16) begin
            reg [7:0] current_char = ascii_str[current_char_index *8 +: 8];
            if (current_char == 8'h20 || current_char == 8'h2C) begin
              if (in_word_reg) begin
                int word_idx = word_count_reg;
                int offset = word_idx * 128;
                temp_words[offset +: 128] = temp_words[offset +: 128] & ((1 << (current_char_pos_reg * 8)) - 1);
                if (word_count_reg < 4)
                  word_count_reg <= word_count_reg + 1;
                in_word_reg <= 0;
                current_char_pos_reg <= 0;
              end
            end else begin
              if (~in_word_reg) begin
                if (word_count_reg < 4) begin
                  in_word_reg <= 1;
                  current_char_pos_reg <= 1;
                  temp_words[word_count_reg * 128 +: 8] <= current_char;
                end
              end else if (current_char_pos_reg < 16) begin
                int word_idx = word_count_reg;
                int offset = word_idx * 128 + (current_char_pos_reg * 8);
                temp_words[offset +: 8] <= current_char;
                current_char_pos_reg <= current_char_pos_reg + 1;
              end
            end
            current_char_index <= current_char_index + 1;
          end else begin
            if (in_word_reg) begin
              int word_idx = word_count_reg;
              int offset = word_idx * 128;
              temp_words[offset +: 128] = temp_words[offset +: 128] & ((1 << (current_char_pos_reg * 8)) - 1);
              if (word_count_reg < 4)
                word_count_reg <= word_count_reg + 1;
              in_word_reg <= 0;
              current_char_pos_reg <= 0;
            end
            state_reg <= DONE;
          end
        end

        DONE: begin
          words <= temp_words;
          word_count <= word_count_reg;
          done <= 1;
          state_reg <= IDLE;
        end

        default: state_reg <= IDLE;
      endcase
    end
  end
endmodule