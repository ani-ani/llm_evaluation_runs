module word_consonant_filter(
  input clk,
  input rst_n,
  input start,
  input [511:0] string_data,
  input [3:0] target_count,
  output reg [7:0] matched_words,
  output reg done
);

  // FSM states
  typedef enum logic [1:0] {IDLE=2'b00, RUN=2'b01, DONE=2'b10} state_t;
  state_t state, next_state;

  // Character stream index (0..63)
  logic [5:0] idx, idx_next;
  // Current char being processed
  logic [7:0] ch;
  // Current word consonant accumulator (0..63 is safe, word <=64 chars)
  logic [5:0] cons_buf, cons_buf_next;
  // Consonant count for the last word that was pushed (when last_char_of_word is asserted)
  logic [5:0] last_consonants, last_consonants_next;
  // Buffer of words, each holds 4-bit consonant count (<=64, fits in 4 bits, 0..15 safe)
  logic [3:0] cons_buf_mem [0:7];
  logic [3:0] cons_buf_mem_next [0:7];
  // Circular write index for words, max 8 words
  logic [2:0] wptr, wptr_next;
  // Word count seen so far (0..8)
  logic [3:0] wcount, wcount_next;
  // Flags to detect word boundaries and valid pushes
  logic in_word, in_word_next;
  logic last_char_of_word, last_char_of_word_next;
  logic push_en, push_en_next;

  // Register updates (sequential block)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      idx <= 6'd0;
      ch <= 8'd0;
      cons_buf <= 6'd0;
      last_consonants <= 6'd0;
      wptr <= 3'd0;
      wcount <= 4'd0;
      in_word <= 1'b0;
      last_char_of_word <= 1'b0;
      push_en <= 1'b0;
      done <= 1'b0;
      matched_words <= 8'd0;
      for (int i = 0; i < 8; i++) cons_buf_mem[i] <= 4'd0;
    end else begin
      state <= next_state;
      idx <= idx_next;
      ch <= string_data[idx*8 +: 8];
      cons_buf <= cons_buf_next;
      last_consonants <= last_consonants_next;
      wptr <= wptr_next;
      wcount <= wcount_next;
      in_word <= in_word_next;
      last_char_of_word <= last_char_of_word_next;
      push_en <= push_en_next;
      done <= (next_state == DONE);
      // matched_words updated on a push (end of each word), aligns with done timing
      if (push_en_next) begin
        matched_words[wptr_next] <= (last_consonants_next == target_count) ? 1'b1 : 1'b0;
        cons_buf_mem[wptr_next] <= last_consonants_next[3:0];
      end
    end
  end

  // Helper: is alphabetic letter?
  logic is_letter;
  assign is_letter = (ch >= "A" && ch <= "Z") || (ch >= "a" && ch <= "z");
  // Helper: is consonant when lowercased
  logic is_consonant;
  logic [7:0] ch_low;
  assign ch_low = (ch >= "A" && ch <= "Z") ? (ch + 8'd32) : ch;
  assign is_consonant = is_letter && !(ch_low == "a" || ch_low == "e" || ch_low == "i" || ch_low == "o" || ch_low == "u");
  // Helper: is space (32)
  logic is_space;
  assign is_space = (ch == 8'd32);

  // Combinational next-state logic
  always_comb begin
    // Defaults
    next_state = state;
    idx_next = idx;
    cons_buf_next = cons_buf;
    last_char_of_word_next = 1'b0;
    push_en_next = 1'b0;
    last_consonants_next = last_consonants;
    wptr_next = wptr;
    wcount_next = wcount;
    in_word_next = in_word;

    case (state)
      IDLE: begin
        // Reset controls on start
        if (start) begin
          idx_next = 6'd0;
          cons_buf_next = 6'd0;
          last_char_of_word_next = 1'b0;
          push_en_next = 1'b0;
          last_consonants_next = 6'd0;
          wptr_next = 3'd0;
          wcount_next = 4'd0;
          in_word_next = 1'b0;
          next_state = RUN;
        end
      end

      RUN: begin
        // Process one character per cycle
        // Update in_word and handle consonant counting for letters
        if (is_letter) begin
          in_word_next = 1'b1;
          cons_buf_next = cons_buf + {5'b0, is_consonant};
        end else begin
          in_word_next = in_word;
          cons_buf_next = cons_buf;
        end

        // Detect end of word on space or last character
        if (is_space) begin
          if (in_word) begin
            // End current word due to space
            last_char_of_word_next = 1'b1;
            last_consonants_next = cons_buf + {5'b0, is_consonant}; // cons already includes this char if letter
            cons_buf_next = 6'd0; // reset for next word
            in_word_next = 1'b0;
            wptr_next = wptr + 1;
            wcount_next = (wcount < 4'd8) ? (wcount + 1) : wcount;
            push_en_next = 1'b1; // push during RUN when word ends by space
          end else begin
            // Multiple spaces: no push
            last_char_of_word_next = 1'b0;
            last_consonants_next = last_consonants;
            push_en_next = 1'b0;
          end
        end else if (idx == 6'd63) begin
          // End of string: push if we were in a word
          if (in_word) begin
            last_char_of_word_next = 1'b1;
            last_consonants_next = cons_buf + {5'b0, is_consonant};
            cons_buf_next = 6'd0;
            wptr_next = wptr + 1;
            wcount_next = (wcount < 4'd8) ? (wcount + 1) : wcount;
            push_en_next = 1'b1;
            next_state = DONE;
          end else begin
            last_char_of_word_next = 1'b0;
            last_consonants_next = last_consonants;
            push_en_next = 1'b0;
            next_state = DONE;
          end
        end else begin
          // Not a space, not last char: no push
          last_char_of_word_next = 1'b0;
          last_consonants_next = last_consonants;
          push_en_next = 1'b0;
        end

        // Advance to next character (if not done)
        if (next_state != DONE) idx_next = idx + 1;
      end

      DONE: begin
        // Hold until next start; matched_words already set by last push
        if (start) begin
          // Restart immediately on new start pulse
          next_state = IDLE;
        end else begin
          next_state = DONE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule
