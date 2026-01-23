module word_guess_solver (
  input clk,
  input rst_n,
  input start,
  input [4:0] n,
  input [127:0] hidden_pattern,
  input [4:0] m,
  input [127:0] word_list [0:15],
  output reg [3:0] result_count,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    LOAD,
    FILTER,
    INTERSECT,
    DONE
  } state_t;

  state_t state;
  reg [3:0] word_idx;
  reg [3:0] pos_idx;
  reg [7:0] revealed_letters [0:15];
  reg [7:0] unknown_letters [0:15];
  reg [15:0] valid_words;
  reg [7:0] intersection [0:15];
  reg [3:0] intersection_count;
  reg [3:0] counter;

  // Reset logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      word_idx <= 0;
      pos_idx <= 0;
      counter <= 0;
      result_count <= 0;
      done <= 0;
      for (int i = 0; i < 16; i++) begin
        revealed_letters[i] <= 0;
        unknown_letters[i] <= 0;
        intersection[i] <= 0;
      end
      valid_words <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD;
            word_idx <= 0;
            pos_idx <= 0;
            counter <= 0;
            result_count <= 0;
            done <= 0;
            for (int i = 0; i < 16; i++) begin
              revealed_letters[i] <= 0;
              unknown_letters[i] <= 0;
              intersection[i] <= 0;
            end
            valid_words <= 0;
          end
        end
        LOAD: begin
          if (counter < n) begin
            if (hidden_pattern[8*counter +: 8] == 8'h2A) begin
              revealed_letters[counter] <= 0;
            end else begin
              revealed_letters[counter] <= hidden_pattern[8*counter +: 8];
            end
            counter <= counter + 1;
            if (counter == n) begin
              state <= FILTER;
              word_idx <= 0;
              pos_idx <= 0;
              counter <= 0;
            end
          end
        end
        FILTER: begin
          if (word_idx < m) begin
            reg valid;
            reg [7:0] current_word [0:15];
            valid = 1;
            for (int i = 0; i < n; i++) begin
              current_word[i] = word_list[word_idx][8*i +: 8];
              if (revealed_letters[i] != 0) begin
                if (current_word[i] != revealed_letters[i]) begin
                  valid = 0;
                end
              end
            end
            if (valid) begin
              valid_words[word_idx] = 1;
              for (int i = 0; i < n; i++) begin
                if (revealed_letters[i] == 0) begin
                  unknown_letters[i] = current_word[i];
                end
              end
            end
            word_idx <= word_idx + 1;
            if (word_idx == m) begin
              state <= INTERSECT;
              word_idx <= 0;
              pos_idx <= 0;
              counter <= 0;
              intersection_count <= 0;
              for (int i = 0; i < 16; i++) begin
                intersection[i] <= 0;
              end
            end
          end
        end
        INTERSECT: begin
          if (word_idx < m) begin
            if (valid_words[word_idx]) begin
              for (int i = 0; i < n; i++) begin
                if (revealed_letters[i] == 0) begin
                  reg found;
                  found = 0;
                  for (int j = 0; j < intersection_count; j++) begin
                    if (intersection[j] == unknown_letters[i]) begin
                      found = 1;
                    end
                  end
                  if (!found) begin
                    intersection[intersection_count] <= unknown_letters[i];
                    intersection_count <= intersection_count + 1;
                  end
                end
              end
            end
            word_idx <= word_idx + 1;
            if (word_idx == m) begin
              state <= DONE;
              result_count <= intersection_count;
              done <= 1;
            end
          end
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