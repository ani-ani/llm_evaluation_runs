module adverb_finder (
  input clk,
  input rst_n,
  input start,
  input [511:0] text,
  output reg [5:0] start_pos,
  output reg [5:0] end_pos,
  output reg [31:0] found_word,
  output reg valid,
  output reg done
);

  reg processing;
  reg [5:0] pos;
  reg in_word;
  reg [5:0] word_start_pos;
  reg [7:0] current_char;
  reg [5:0] word_length;
  reg [7:0] last_valid_char;
  reg [7:0] second_last_valid_char;
  reg [2:0] word_char_count;

  wire is_letter = (current_char >= 8'h41 && current_char <= 8'h5A) || 
                   (current_char >= 8'h61 && current_char <= 8'h7A);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      processing <= 0;
      pos <= 0;
      in_word <= 0;
      word_start_pos <= 0;
      last_valid_char <= 0;
      second_last_valid_char <= 0;
      word_length <= 0;
      found_word <= 0;
      start_pos <= 0;
      end_pos <= 0;
      valid <= 0;
      done <= 0;
      word_char_count <= 0;
    end else begin
      done <= 0;
      valid <= 0;

      if (start && !processing) begin
        processing <= 1;
        pos <= 0;
        in_word <= 0;
        word_start_pos <= 0;
        last_valid_char <= 0;
        second_last_valid_char <= 0;
        word_length <= 0;
        found_word <= 0;
        word_char_count <= 0;
      end else if (processing) begin
        current_char = text[pos*8 +: 8];

        if (!in_word) begin
          if (is_letter) begin
            in_word <= 1;
            word_start_pos <= pos;
            word_length <= 1;
            last_valid_char <= current_char;
            found_word <= {current_char, 24'b0};
            word_char_count <= 3'd1;
          end
        end else begin
          if (is_letter) begin
            word_length <= word_length + 1;
            if (word_length >= 1)
              second_last_valid_char <= last_valid_char;
            last_valid_char <= current_char;

            if (word_char_count < 3'd4) begin
              case (word_char_count)
                3'd1: found_word[23:16] <= current_char;
                3'd2: found_word[15:8] <= current_char;
                3'd3: found_word[7:0] <= current_char;
                default: ;
              endcase
              word_char_count <= word_char_count + 1;
            end
          end

          if (!is_letter || pos == 6'd63) begin
            in_word <= 0;
            if (word_length >= 2 && last_valid_char == 8'h79 && second_last_valid_char == 8'h6C) begin
              start_pos <= word_start_pos;
              end_pos <= pos + 1;
              valid <= 1;
              done <= 1;
              processing <= 0;
            end else if (pos == 6'd63) begin
              done <= 1;
              processing <= 0;
            end
          end
        end

        if (pos == 6'd63) begin
          done <= 1;
          processing <= 0;
        end else
          pos <= pos + 1;
      end
    end
  end
endmodule