module adverb_finder(
  input reg clk, rst_n, start,
  input reg [511:0] text,
  output reg [5:0] start_pos, end_pos,
  output reg [127:0] found_word,
  output reg done
);

  // Internal state
  reg [1:0] state;
  reg [5:0] position;
  reg in_word;
  reg [5:0] current_start;
  reg [5:0] current_end;
  reg [7:0] last_char;
  reg [7:0] second_last_char;
  reg [3:0] word_len;
  reg [127:0] current_word;

  localparam IDLE = 2'b00;
  localparam SCANNING = 2'b01;
  localparam DONE = 2'b10;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      in_word <= 1'b0;
      position <= 6'b0;
      current_start <= 6'b0;
      current_end <= 6'b0;
      last_char <= 8'b0;
      second_last_char <= 8'b0;
      word_len <= 4'b0;
      current_word <= 128'b0;
      start_pos <= 6'b0;
      end_pos <= 6'b0;
      found_word <= 128'b0;
    end
    else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SCANNING;
            done <= 1'b0;
            in_word <= 1'b0;
            position <= 6'b0;
            current_start <= 6'b0;
            current_end <= 6'b0;
            last_char <= 8'b0;
            second_last_char <= 8'b0;
            word_len <= 4'b0;
            current_word <= 128'b0;
            start_pos <= 6'b0;
            end_pos <= 6'b0;
            found_word <= 128'b0;
          end
        end
        SCANNING: begin
          // Get current character
          reg [7:0] char;
          char = text[(position*8) +: 8];
          reg is_word_char;
          is_word_char = ((char >= 8'h41) && (char <= 8'h5A)) || ((char >= 8'h61) && (char <= 8'h7A));

          if (in_word) begin
            if (is_word_char) begin
              // Continue in word
              current_end <= position;
              word_len <= word_len + 1;
              if (word_len >= 1) begin
                second_last_char <= last_char;
              end
              last_char <= char;
              if (word_len < 15) begin
                current_word <= {current_word[119:0], char};
              end
            end
            else begin
              // End of word
              in_word <= 1'b0;
              if (word_len >= 2) begin
                if ((second_last_char == 8'h6C) && (last_char == 8'h79)) begin
                  // Found match
                  start_pos <= current_start;
                  end_pos <= current_end;
                  found_word <= current_word;
                  state <= DONE;
                  done <= 1'b1;
                end
              end
            end
          end
          else begin
            if (is_word_char) begin
              // Start of a new word
              in_word <= 1'b1;
              current_start <= position;
              current_end <= position;
              word_len <= 1;
              last_char <= char;
              // current_word: store the first character
              current_word <= {120'b0, char};
            end
          end

          // Advance position
          if (position < 63) begin
            position <= position + 1;
          end
          else begin
            // Reached the end of the text
            if (in_word) begin
              in_word <= 1'b0;
              if (word_len >= 2) begin
                if ((second_last_char == 8'h6C) && (last_char == 8'h79)) begin
                  start_pos <= current_start;
                  end_pos <= current_end;
                  found_word <= current_word;
                  state <= DONE;
                  done <= 1'b1;
                end
                else begin
                  state <= DONE;
                  done <= 1'b1;
                  start_pos <= 6'b0;
                  end_pos <= 6'b0;
                  found_word <= 128'b0;
                end
              end
              else begin
                state <= DONE;
                done <= 1'b1;
                start_pos <= 6'b0;
                end_pos <= 6'b0;
                found_word <= 128'b0;
              end
            end
            else begin
              state <= DONE;
              done <= 1'b1;
              start_pos <= 6'b0;
              end_pos <= 6'b0;
              found_word <= 128'b0;
            end
          end
        end
        DONE: begin
          if (start) begin
            // Start a new scan
            state <= SCANNING;
            done <= 1'b0;
            in_word <= 1'b0;
            position <= 6'b0;
            current_start <= 6'b0;
            current_end <= 6'b0;
            last_char <= 8'b0;
            second_last_char <= 8'b0;
            word_len <= 4'b0;
            current_word <= 128'b0;
            start_pos <= 6'b0;
            end_pos <= 6'b0;
            found_word <= 128'b0;
          end
        end
      endcase
    end
  end

endmodule
