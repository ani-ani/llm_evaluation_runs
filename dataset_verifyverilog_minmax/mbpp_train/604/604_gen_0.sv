module reverse_words (
  input clk,
  input rst_n,
  input start,
  input [127:0] str,
  output reg [127:0] reversed_str,
  output reg done
);

  // FSM states
  typedef enum logic [2:0] {
    IDLE = 3'b000,
    TRIM = 3'b001,
    READ_WORD = 3'b010,
    DONE = 3'b011
  } state_t;
  state_t state, next_state;

  // Parsing and word-stack control
  reg [3:0] char_idx;          // 0..15 (fits in 4 bits)
  reg [1:0] words_found;       // 0..4
  reg [5:0] out_idx;           // byte index in output buffer: 0..15
  reg [7:0] word_buf [0:7];    // up to 8 chars per word
  reg [3:0] word_len;          // 0..8
  reg [3:0] put_ptr;           // write pointer within current word (0..7)

  // Next-state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE:   next_state = start ? TRIM : IDLE;
      TRIM: begin
        if (char_idx >= 4'd15) begin
          next_state = DONE;
        end else begin
          // Skip leading/multiple spaces
          if (str[char_idx*8 +: 8] == 8'h20) begin
            next_state = TRIM; // stay and increment char_idx in FF
          end else begin
            next_state = READ_WORD; // start capturing word
          end
        end
      end
      READ_WORD: begin
        if (word_len == 4'd8) begin
          // max word length reached, commit word
          next_state = TRIM;
        end else begin
          if (char_idx >= 4'd15) begin
            next_state = DONE;
          end else begin
            // Decide next step after capturing this char in FF
            next_state = (str[char_idx*8 +: 8] == 8'h20) ? TRIM : READ_WORD;
          end
        end
      end
      DONE:   next_state = start ? DONE : IDLE; // stay done until start deasserted
      default: next_state = IDLE;
    endcase
  end

  // State and control register updates
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      char_idx <= 4'd0;
      words_found <= 2'd0;
      out_idx <= 6'd0;
      word_len <= 4'd0;
      put_ptr <= 4'd0;
      done <= 1'b0;
      reversed_str <= 128'h0;
    end else begin
      state <= next_state;
      done <= 1'b0;

      case (state)
        IDLE: begin
          char_idx <= 4'd0;
          words_found <= 2'd0;
          out_idx <= 6'd0;
          word_len <= 4'd0;
          put_ptr <= 4'd0;
          reversed_str <= 128'h0;
        end

        TRIM: begin
          // clear transient word capture
          word_len <= 4'd0;
          put_ptr <= 4'd0;
          if (next_state == READ_WORD) begin
            // about to read first char of a word
            char_idx <= char_idx; // no change this cycle
          end else begin
            // skip spaces or terminate if done
            if (char_idx < 4'd15) char_idx <= char_idx + 1;
          end
          words_found <= words_found; // unchanged
          out_idx <= out_idx;
        end

        READ_WORD: begin
          // Capture current character into temporary buffer
          if (word_len < 4'd8) begin
            word_buf[put_ptr] <= str[char_idx*8 +: 8];
            put_ptr <= put_ptr + 1;
            word_len <= word_len + 1;
            char_idx <= char_idx + 1;
          end

          if (next_state == TRIM || next_state == DONE) begin
            // Commit captured word to output in reverse order
            if (words_found < 2'd4) begin
              // Determine where to write this word (reverse order)
              // words_found=0 -> last word -> back half of buffer
              // words_found=3 -> first word -> front of buffer
              reg [3:0] w_rev;
              w_rev = 3 - words_found;
              // Start index in output (16 bytes total, last 8 bytes for w_rev=0)
              out_idx <= w_rev * 4'd8;
              // Write all word_len characters into reversed_str (MSB at higher byte addr)
              for (int k = 0; k < 8; k = k + 1) begin
                if (k < word_len) begin
                  // Place char k at position start + k
                  reversed_str[(out_idx + k)*8 +: 8] <= word_buf[k];
                end
              end
              words_found <= words_found + 1;
            end
            // Reset word capture for next word (if any)
            word_len <= 4'd0;
            put_ptr <= 4'd0;
          end
        end

        DONE: begin
          // Pad any remaining bytes in reversed_str with spaces (0x20)
          for (int p = 0; p < 16; p = p + 1) begin
            if (reversed_str[p*8 +: 8] === 8'h00) begin // treat unspecified as space
              reversed_str[p*8 +: 8] <= 8'h20;
            end
          end
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

endmodule
