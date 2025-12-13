module word_guess_analyzer(
  input        clk,
  input        rst_n,
  input        start,
  input  [3:0] n,
  input  [95:0] revealed_chars, // 16 * (1'b is_revealed, 5'b char)
  input  [3:0] m,
  input  [79:0] word_data,      // 16 * 5b chars
  input        word_valid,
  output reg [4:0] result,
  output reg       done
);

  // FSM states
  typedef enum logic [2:0] {
    S_IDLE    = 3'd0,
    S_WAIT    = 3'd1,
    S_PROC    = 3'd2,
    S_FINAL1  = 3'd3,
    S_FINAL2  = 3'd4
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [3:0]  word_count;          // number of words processed
  reg        first_valid_seen;    // indicates first valid word used to init intersection
  reg [25:0] inter_mask;          // intersection of hidden letters across valid words
  reg [25:0] revealed_mask;       // letters appearing in revealed positions

  // Helper wires
  wire [3:0] n_eff = (n == 4'd0) ? 4'd0 : n;  // safety
  wire [3:0] m_eff = (m == 4'd0) ? 4'd0 : m;

  integer i;

  // Build revealed_mask combinationally from revealed_chars and n
  // revealed_chars layout per position i: [6*i+5] is_revealed, [6*i+4 -: 5] char
  always @(*) begin
    revealed_mask = 26'd0;
    for (i = 0; i < 16; i = i + 1) begin
      if (i < n_eff) begin
        if (revealed_chars[i*6 + 5]) begin
          // is_revealed == 1
          if (revealed_chars[i*6 + 4 -: 5] < 5'd26)
            revealed_mask[revealed_chars[i*6 + 4 -: 5]] = 1'b1;
        end
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_WAIT;
      end

      S_WAIT: begin
        // Wait for first word_valid or decide immediate if m==0
        if (m_eff == 0)
          next_state = S_FINAL1; // no words: finalize quickly
        else if (word_valid)
          next_state = S_PROC;
      end

      S_PROC: begin
        // Stay in PROC until all m words processed
        if ((word_count == m_eff) && !word_valid) begin
          // last word already counted, move to finalize
          next_state = S_FINAL1;
        end
      end

      S_FINAL1: begin
        next_state = S_FINAL2;
      end

      S_FINAL2: begin
        next_state = S_IDLE;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Main sequential block
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= S_IDLE;
      word_count       <= 4'd0;
      first_valid_seen <= 1'b0;
      inter_mask       <= 26'd0;
      result           <= 5'd0;
      done             <= 1'b0;
    end else begin
      state <= next_state;
      done  <= 1'b0; // default, pulsed only in S_FINAL2

      case (state)
        S_IDLE: begin
          result           <= 5'd0;
          word_count       <= 4'd0;
          first_valid_seen <= 1'b0;
          inter_mask       <= 26'h3FFFFFF; // start as all-ones mask
          if (start) begin
            // prep happens here, revealed_mask is combinational
          end
        end

        S_WAIT: begin
          // Reset counters on entering WAIT from IDLE via start
          if (start) begin
            word_count       <= 4'd0;
            first_valid_seen <= 1'b0;
            inter_mask       <= 26'h3FFFFFF;
          end
          // If no words (m==0) finalization handled by state machine
          if (word_valid && (m_eff != 0)) begin
            // Will be processed in PROC on next cycle
          end
        end

        S_PROC: begin
          // Process one word per cycle when word_valid is high, as long as word_count < m
          if (word_valid && (word_count < m_eff)) begin
            // Evaluate this word
            reg        valid_word;
            reg [25:0] hidden_mask;
            reg [4:0]  pos_char;
            reg        pos_is_revealed;
            integer    j;

            valid_word  = 1'b1;
            hidden_mask = 26'd0;

            // Check each position
            for (j = 0; j < 16; j = j + 1) begin
              if (j < n_eff) begin
                pos_is_revealed = revealed_chars[j*6 + 5];
                pos_char        = word_data[j*5 + 4 -: 5];

                if (pos_is_revealed) begin
                  // Must match revealed char
                  if (pos_char != revealed_chars[j*6 + 4 -: 5])
                    valid_word = 1'b0;
                end else begin
                  // Hidden position: must not be any revealed letter
                  if (pos_char < 5'd26) begin
                    if (revealed_mask[pos_char])
                      valid_word = 1'b0;
                    else
                      hidden_mask[pos_char] = 1'b1;
                  end
                end
              end else begin
                // Positions beyond n: ignore
              end
            end

            // Update intersection if word is valid
            if (valid_word) begin
              if (!first_valid_seen) begin
                inter_mask       <= hidden_mask;
                first_valid_seen <= 1'b1;
              end else begin
                inter_mask <= inter_mask & hidden_mask;
              end
            end

            // Increment processed word count
            word_count <= word_count + 4'd1;
          end

          // When m words processed, next_state moves to FINAL1 once word_valid deasserts
        end

        S_FINAL1: begin
          // Compute popcount of inter_mask into result (1st finalize cycle)
          integer k;
          reg [4:0] cnt;
          cnt = 5'd0;
          for (k = 0; k < 26; k = k + 1) begin
            if (inter_mask[k])
              cnt = cnt + 5'd1;
          end
          result <= cnt;
        end

        S_FINAL2: begin
          // Second finalize cycle: assert done
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

endmodule