module word_consonant_filter (
  input clk,
  input rst_n,
  input start,
  input [511:0] string_data,
  input [3:0] target_count,
  output reg [7:0] matched_words,
  output reg done
);

  typedef enum logic [1:0] {IDLE, PROCESSING, DONE_ST} state_t;
  state_t state;

  reg [5:0] char_counter;
  reg [2:0] word_counter;
  reg [5:0] current_consonant_count;
  reg [5:0] word_consonants [0:7];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      matched_words <= 8'b0;
      char_counter <= 6'b0;
      word_counter <= 3'b0;
      current_consonant_count <= 6'b0;
      for (int i=0; i<8; i++) begin
        word_consonants[i] <= 6'b0;
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          matched_words <= 8'b0;
          if (start) begin
            state <= PROCESSING;
            char_counter <= 6'b0;
            word_counter <= 3'b0;
            current_consonant_count <= 6'b0;
            for (int i=0; i<8; i++) begin
              word_consonants[i] <= 6'b0;
            end
          end
        end

        PROCESSING: begin
          reg [7:0] current_char = string_data[char_counter*8 +: 8];
          reg [7:0] lowercase_char;
          reg end_processing;

          lowercase_char = (current_char >= 8'h41 && current_char <= 8'h5A) ? current_char + 8'h20 : current_char;
          end_processing = (char_counter == 6'd63) || (word_counter == 3'd7);

          if (lowercase_char == 8'h20) begin
            word_consonants[word_counter] <= current_consonant_count;
            if (word_counter < 3'd7) begin
              word_counter <= word_counter + 1;
            end
            current_consonant_count <= 6'b0;
          end else begin
            if ((lowercase_char >= 8'h62 && lowercase_char <= 8'h64) ||
                (lowercase_char >= 8'h66 && lowercase_char <= 8'h68) ||
                (lowercase_char >= 8'h6A && lowercase_char <= 8'h6E) ||
                (lowercase_char >= 8'h70 && lowercase_char <= 8'h74) ||
                (lowercase_char >= 8'h76 && lowercase_char <= 8'h7A)) begin
              current_consonant_count <= current_consonant_count + 1;
            end
          end

          if (char_counter != 6'd63) begin
            char_counter <= char_counter + 1;
          end

          if (end_processing) begin
            if (lowercase_char != 8'h20 && word_counter < 3'd7) begin
              word_consonants[word_counter] <= current_consonant_count;
              word_counter <= word_counter + 1;
            end
            state <= DONE_ST;
          end
        end

        DONE_ST: begin
          for (int i=0; i<8; i++) begin
            matched_words[i] <= (word_consonants[i] == target_count);
          end
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule