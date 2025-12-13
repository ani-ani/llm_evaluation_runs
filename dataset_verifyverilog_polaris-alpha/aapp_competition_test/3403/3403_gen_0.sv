module query_step_calculator(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // start processing
  input [63:0] query_word, // 8 chars (8 bits per char)
  output reg [6:0] step_count, // max steps = 8 words + 8*8 chars = 72
  output reg done // high when calculation complete
);

  // Database
  localparam [7:0][63:0] DB = {
    64'h686F626F746E6963, // 'hobotnic'
    64'h726F626F745F5F5F, // 'robot___'
    64'h686F62695F5F5F5F, // 'hobi____'
    64'h686F6269745F5F5F, // 'hobit___'
    64'h726F62695F5F5F5F, // 'robi____'
    64'h5F5F5F5F5F5F5F5F, // empty
    64'h5F5F5F5F5F5F5F5F, // empty
    64'h5F5F5F5F5F5F5F5F  // empty
  };

  // States
  typedef enum logic [2:0] {
    IDLE         = 3'd0,
    COMPARE_WORD = 3'd1,
    CHECK_CHAR   = 3'd2,
    ACCUMULATE   = 3'd3,
    DONE         = 3'd4
  } state_t;

  state_t state, next_state;

  reg [2:0] word_idx;    // 0..7
  reg [2:0] char_idx;    // 0..7
  reg [6:0] next_step_count;
  reg [2:0] next_word_idx;
  reg [2:0] next_char_idx;
  reg       word_match;      // exact word match flag (combinational)
  reg       lcp_done;        // LCP search complete for current word
  reg       lcp_match_exact; // query == DB[word_idx]

  // Extract current DB word
  wire [63:0] db_word = DB[word_idx];

  // Combinational LCP/word-match for current char index
  wire [7:0] db_char    = db_word[ (7-char_idx)*8 +: 8 ];
  wire [7:0] query_char = query_word[ (7-char_idx)*8 +: 8 ];
  wire       char_equal = (db_char == query_char);

  // Next-state logic
  always @* begin
    // Defaults
    next_state       = state;
    next_step_count  = step_count;
    next_word_idx    = word_idx;
    next_char_idx    = char_idx;
    word_match       = 1'b0;
    lcp_done         = 1'b0;
    lcp_match_exact  = 1'b0;

    case (state)
      IDLE: begin
        if (start) begin
          next_step_count = 7'd0;
          next_word_idx   = 3'd0;
          next_char_idx   = 3'd0;
          next_state      = COMPARE_WORD;
        end
      end

      COMPARE_WORD: begin
        // Add 1 step for word comparison
        next_step_count = step_count + 7'd1;
        // Check exact word match
        if (query_word == db_word) begin
          // Exact match: done after counting this word comparison
          word_match      = 1'b1;
          lcp_match_exact = 1'b1;
          next_state      = DONE;
        end else begin
          // Not exact match: start LCP character-wise comparison
          next_char_idx = 3'd0;
          next_state    = CHECK_CHAR;
        end
      end

      CHECK_CHAR: begin
        // Compare characters for LCP
        if (char_equal) begin
          // Characters match at this index
          if (char_idx == 3'd7) begin
            // Matched all 8 chars but word != db_word (shouldn't occur), treat as full LCP
            lcp_done        = 1'b1;
            lcp_match_exact = 1'b0;
            next_state      = ACCUMULATE;
          end else begin
            // Continue to next character
            next_char_idx = char_idx + 3'd1;
            next_state    = CHECK_CHAR;
          end
        end else begin
          // Mismatch: LCP ends before this char
          lcp_done   = 1'b1;
          next_state = ACCUMULATE;
        end
      end

      ACCUMULATE: begin
        // LCP length is char_idx when mismatch occurred, or 8 when all matched.
        // In CHECK_CHAR, on mismatch, char_idx is index of mismatching char,
        // so LCP length = char_idx. On full match (char_idx==7 and equal), we set lcp_done
        // and come here with LCP length = 8.
        if (char_equal && (char_idx == 3'd7)) begin
          // All 8 chars matched during final CHECK_CHAR cycle
          next_step_count = step_count + 7'd8;
        end else begin
          // Mismatch occurred at current char_idx; LCP length = char_idx
          next_step_count = step_count + char_idx;
        end

        // Proceed to next word or finish
        if (word_idx == 3'd7) begin
          next_state = DONE;
        end else begin
          next_word_idx = word_idx + 3'd1;
          next_char_idx = 3'd0;
          next_state    = COMPARE_WORD;
        end
      end

      DONE: begin
        // Wait here until start is deasserted, then go back to IDLE
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      step_count  <= 7'd0;
      word_idx    <= 3'd0;
      char_idx    <= 3'd0;
      done        <= 1'b0;
    end else begin
      state      <= next_state;
      step_count <= next_step_count;
      word_idx   <= next_word_idx;
      char_idx   <= next_char_idx;

      // done signal
      case (next_state)
        DONE: done <= 1'b1;
        default: if (state == IDLE && start) done <= 1'b0; // clear on new start
      endcase
    end
  end

endmodule