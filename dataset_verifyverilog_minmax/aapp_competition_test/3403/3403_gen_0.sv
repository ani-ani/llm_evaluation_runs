module query_step_calculator(
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [63:0] query_word,
  output reg [6:0] step_count,
  output reg done
);

  // Internal database: 8 words of 8 characters each (64 bits)
  localparam [7:0][63:0] DB = {
    64'h686F626F746E6963, // 'hobotnic' (truncated to 8 chars)
    64'h726F626F745F5F5F, // 'robot___' (padded)
    64'h686F62695F5F5F5F, // 'hobi____'
    64'h686F6269745F5F5F, // 'hobit___'
    64'h726F62695F5F5F5F, // 'robi____'
    64'h5F5F5F5F5F5F5F5F, // Empty slots
    64'h5F5F5F5F5F5F5F5F,
    64'h5F5F5F5F5F5F5F5F
  };

  // State definitions
  typedef enum logic [2:0] {
    IDLE        = 3'b000,
    COMPARE_WORD= 3'b001,
    CHECK_CHAR  = 3'b010,
    ACCUMULATE  = 3'b011,
    DONE        = 3'b100
  } state_t;

  state_t state, next_state;

  // Indexes and counters
  reg [2:0] word_idx;   // 0 to 7
  reg [2:0] char_idx;   // 0 to 7
  reg [3:0] lcp_count;  // 0 to 8

  // Sequential block: state update and reset
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      step_count <= 7'b0;
      done    <= 1'b0;
      word_idx   <= 3'b0;
      char_idx   <= 3'b0;
      lcp_count  <= 4'b0;
    end else begin
      state   <= next_state;
      // Outputs and counters are updated in combinational logic,
      // but they can be assigned here as well for safety.
    end
  end

  // Combinational logic: state machine
  always_comb begin
    // Default values
    next_state = state;
    done = 1'b0;
    step_count = step_count; // hold current value until updated
    // All indexes hold current values until changed
    case (state)
      IDLE: begin
        done = 1'b0;
        if (start) begin
          // Initialize for new processing
          next_state = COMPARE_WORD;
          word_idx = 3'b0;
          char_idx = 3'b0;
          lcp_count = 4'b0;
          step_count = 7'b0; // clear step count on new start
        end else begin
          // Remain idle
          next_state = IDLE;
        end
      end

      COMPARE_WORD: begin
        // Start a new word comparison
        char_idx = 3'b0;
        lcp_count = 4'b0;
        next_state = CHECK_CHAR;
      end

      CHECK_CHAR: begin
        if (char_idx < 3'd8) begin
          // Compare the current character
          if (query_word[char_idx*8 +: 8] == DB[word_idx][char_idx*8 +: 8]) begin
            // Characters match: increment LCP counter and char index
            char_idx = char_idx + 1;
            lcp_count = lcp_count + 1;
            // Stay in CHECK_CHAR to examine next character
            next_state = CHECK_CHAR;
          end else begin
            // Mismatch: move to accumulation
            next_state = ACCUMULATE;
          end
        end else begin
          // All 8 characters matched => exact match
          next_state = ACCUMULATE;
        end
      end

      ACCUMULATE: begin
        // Add 1 (comparison of the word) + LCP length to step count
        step_count = step_count + 1 + lcp_count;

        // Determine if we have an exact match
        if (lcp_count == 4'd8) begin
          // Found exact match: finish
          next_state = DONE;
        end else begin
          // Not exact, go to next word
          word_idx = word_idx + 1;
          if (word_idx >= 3'd8) begin
            // No more words in DB
            next_state = DONE;
          end else begin
            // Compare next word
            next_state = COMPARE_WORD;
          end
        end
      end

      DONE: begin
        done = 1'b1;
        // Hold the result until a new start is asserted
        if (!start) begin
          next_state = IDLE;
          // Clear counters for a fresh start
          step_count = 7'b0;
          word_idx = 3'b0;
          char_idx = 3'b0;
          lcp_count = 4'b0;
        end else begin
          // Stay in DONE if start is kept high
          next_state = DONE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule
