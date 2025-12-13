module word_splitter(
  input              clk,
  input              rst_n,
  input              start,
  input      [127:0] ascii_str,
  output reg [511:0] words,
  output reg [3:0]   word_count,
  output reg         done
);

  // State encoding
  localparam IDLE  = 2'b00;
  localparam PROC  = 2'b01;
  localparam DONE  = 2'b10;

  reg [1:0]  state, next_state;
  reg [3:0]  idx;             // index 0..15 (character index)
  reg [1:0]  word_idx;        // word index 0..3
  reg [3:0]  char_idx;        // char index inside a word 0..15
  reg        in_word;         // indicates we are currently inside a word

  // Extract character from ascii_str
  wire [7:0] curr_char;
  assign curr_char = ascii_str[8*(15-idx) +: 8];

  // Delimiter detection
  wire is_delim;
  assign is_delim = (curr_char == 8'h2C) || (curr_char == 8'h20);

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = PROC;
      end
      PROC: begin
        if (idx == 4'd15)
          next_state = DONE;
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Main sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      idx        <= 4'd0;
      word_idx   <= 2'd0;
      char_idx   <= 4'd0;
      in_word    <= 1'b0;
      words      <= 512'd0;
      word_count <= 4'd0;
      done       <= 1'b0;
    end else begin
      state <= next_state;

      // Default outputs each cycle
      done <= 1'b0;

      case (state)
        IDLE: begin
          if (start) begin
            idx        <= 4'd0;
            word_idx   <= 2'd0;
            char_idx   <= 4'd0;
            in_word    <= 1'b0;
            words      <= 512'd0;   // clear all words
            word_count <= 4'd0;
          end
        end

        PROC: begin
          // Process current character at index idx
          if (is_delim) begin
            // Delimiter: end current word if in_word
            if (in_word) begin
              in_word <= 1'b0;
              // Word completed; increment word_count if within limit
              if (word_idx < 2'd4) begin
                word_count <= word_count + 4'd1;
                if (word_idx != 2'd3) begin
                  word_idx <= word_idx + 2'd1;
                  char_idx <= 4'd0;
                end
              end
            end
          end else begin
            // Non-delimiter character
            if (!in_word) begin
              // Starting a new word if room remains
              if (word_idx < 2'd4) begin
                in_word  <= 1'b1;
                char_idx <= 4'd0;
                // fall through to store character below
              end
            end

            if (in_word && (word_idx < 2'd4) && (char_idx < 4'd16)) begin
              // Store character into words
              // words layout: word0 [511:384], word1 [383:256], word2 [255:128], word3 [127:0]
              // word i: base = 511 - i*128 - 7; index within word = char_idx
              integer bit_pos;
              bit_pos = 511 - (word_idx * 128) - (char_idx * 8) - 7;
              words[bit_pos +: 8] <= curr_char;

              // Advance char index if not at end
              if (char_idx != 4'd15)
                char_idx <= char_idx + 4'd1;
            end
          end

          // Advance idx
          if (idx != 4'd15)
            idx <= idx + 4'd1;
        end

        DONE: begin
          // Finalize word_count if last char ended an active word without trailing delimiter
          if (in_word && (word_idx < 2'd4)) begin
            // Close the last word once
            word_count <= word_count + 4'd1;
          end
          in_word <= 1'b0;

          done <= 1'b1;  // Assert done for one cycle
        end

        default: begin
        end
      endcase
    end
  end

endmodule