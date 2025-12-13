module verse_pattern_matcher(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start processing
  input [3:0][3:0] pattern, // 4 lines of syllable counts (4-bit per line)
  input [3:0][15:0][7:0] text_lines, // 4 lines, 16 chars each (ASCII)
  output reg match, // 1=YES, 0=NO
  output reg done // High when processing complete
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE          = 2'b00,
    COUNT_VOWELS  = 2'b01,
    COMPARE       = 2'b10,
    DONE          = 2'b11
  } state_t;

  state_t state, next_state;

  // Line and character indices
  reg [1:0]  line_idx;       // 0..3
  reg [4:0]  char_idx;       // 0..16 (allows counting up to 16 chars)

  // Vowel counter (0-15) per line
  reg [3:0]  vowel_count;

  // Internal flag indicating overall match remains valid
  reg        match_accum;

  // Current character
  wire [7:0] curr_char;
  assign curr_char = text_lines[line_idx][char_idx];

  // Vowel detection
  wire is_vowel;
  assign is_vowel = (curr_char == "a") ||
                    (curr_char == "e") ||
                    (curr_char == "i") ||
                    (curr_char == "o") ||
                    (curr_char == "u") ||
                    (curr_char == "y");

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = COUNT_VOWELS;
      end

      COUNT_VOWELS: begin
        // After processing 16 characters, move to COMPARE
        if (char_idx == 5'd16)
          next_state = COMPARE;
      end

      COMPARE: begin
        // If mismatch or last line processed, go to DONE
        // Else process next line
        if (!match_accum)
          next_state = DONE;
        else if (line_idx == 2'd3)
          next_state = DONE;
        else
          next_state = COUNT_VOWELS;
      end

      DONE: begin
        // Wait in DONE until start is deasserted; then go IDLE
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      line_idx    <= 2'd0;
      char_idx    <= 5'd0;
      vowel_count <= 4'd0;
      match_accum <= 1'b1;
      match       <= 1'b0;
      done        <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          // Reset outputs and internal registers when (re)starting
          done        <= 1'b0;
          match       <= 1'b0;
          if (start) begin
            line_idx    <= 2'd0;
            char_idx    <= 5'd0;
            vowel_count <= 4'd0;
            match_accum <= 1'b1;
          end
        end

        COUNT_VOWELS: begin
          // Count vowels over 16 cycles per line
          if (char_idx < 5'd16) begin
            if (is_vowel && (vowel_count != 4'hF)) begin
              // Saturate at 15 to stay within 4 bits
              vowel_count <= vowel_count + 4'd1;
            end
            char_idx <= char_idx + 5'd1;
          end
        end

        COMPARE: begin
          // Compare vowel_count with pattern for current line
          if (vowel_count != pattern[line_idx]) begin
            match_accum <= 1'b0; // early termination condition
          end

          if (!match_accum || (vowel_count != pattern[line_idx])) begin
            // Mismatch: no need to process further lines
            match_accum <= 1'b0;
          end else begin
            // Match for this line; move to next if any
            if (line_idx < 2'd3) begin
              line_idx    <= line_idx + 2'd1;
              char_idx    <= 5'd0;
              vowel_count <= 4'd0;
            end
          end
        end

        DONE: begin
          // Latch final result
          done  <= 1'b1;
          match <= match_accum;
          // Stay here until start is deasserted; no state changes inside
        end

        default: begin
          // Safety reset
          state       <= IDLE;
          line_idx    <= 2'd0;
          char_idx    <= 5'd0;
          vowel_count <= 4'd0;
          match_accum <= 1'b1;
          match       <= 1'b0;
          done        <= 1'b0;
        end
      endcase
    end
  end

endmodule