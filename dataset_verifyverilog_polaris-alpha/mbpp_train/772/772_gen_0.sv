module word_length_filter(
  input              clk,
  input              rst_n,
  input              start,
  input      [255:0] str_in,
  input      [2:0]   K,
  output reg [255:0] str_out,
  output reg         done
);

  // State encoding
  localparam IDLE      = 3'd0;
  localparam PARSE     = 3'd1;
  localparam COMPARE   = 3'd2;
  localparam BUILD_OUT = 3'd3;
  localparam DONE      = 3'd4;

  reg [2:0]  state, next_state;

  // Input traversal index (0..31)
  reg [5:0]  in_idx;
  reg [5:0]  next_in_idx;

  // Output traversal index (0..31)
  reg [5:0]  out_idx;
  reg [5:0]  next_out_idx;

  // Current word length counter
  reg [3:0]  word_len;
  reg [3:0]  next_word_len;

  // Indicates we are currently inside a word
  reg        in_word;
  reg        next_in_word;

  // Latched character for multi-cycle operations
  reg [7:0]  curr_char;
  reg [7:0]  next_curr_char;

  // Hold last selected word_len for compare/build pipeline
  reg [3:0]  hold_word_len;
  reg [3:0]  next_hold_word_len;

  // Flag to indicate if previous output ended with a word (for spacing)
  reg        has_prev_word;
  reg        next_has_prev_word;

  // Internal done flag
  reg        done_int;
  reg        next_done_int;

  // Extract character from str_in by index
  wire [7:0] in_char;
  assign in_char = str_in[255 - in_idx*8 -: 8];

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= IDLE;
      in_idx         <= 6'd0;
      out_idx        <= 6'd0;
      word_len       <= 4'd0;
      in_word        <= 1'b0;
      curr_char      <= 8'd0;
      hold_word_len  <= 4'd0;
      has_prev_word  <= 1'b0;
      str_out        <= 256'd0;
      done           <= 1'b0;
      done_int       <= 1'b0;
    end else begin
      state          <= next_state;
      in_idx         <= next_in_idx;
      out_idx        <= next_out_idx;
      word_len       <= next_word_len;
      in_word        <= next_in_word;
      curr_char      <= next_curr_char;
      hold_word_len  <= next_hold_word_len;
      has_prev_word  <= next_has_prev_word;
      str_out        <= str_out; // updated combinationally when needed via blocking assignments below
      done_int       <= next_done_int;
      done           <= done_int;
    end
  end

  // Combinational next-state logic and output construction
  always @* begin
    // Default assignments
    next_state         = state;
    next_in_idx        = in_idx;
    next_out_idx       = out_idx;
    next_word_len      = word_len;
    next_in_word       = in_word;
    next_curr_char     = curr_char;
    next_hold_word_len = hold_word_len;
    next_has_prev_word = has_prev_word;
    next_done_int      = 1'b0;

    // str_out mainly updated in BUILD_OUT state using blocking assignments

    case (state)
      IDLE: begin
        if (start) begin
          // Initialize for new processing
          next_in_idx        = 6'd0;
          next_out_idx       = 6'd0;
          next_word_len      = 4'd0;
          next_in_word       = 1'b0;
          next_has_prev_word = 1'b0;
          next_hold_word_len = 4'd0;
          next_curr_char     = 8'd0;
          next_state         = PARSE;
          // Clear output
          // Synchronous clear via sequential block: emulate by driving zeros when leaving IDLE on start
        end
      end

      PARSE: begin
        // Load current character and determine word boundaries
        if (in_idx < 6'd32) begin
          next_curr_char = in_char;
          if (in_char != 8'h20 && in_char != 8'h00) begin
            // Non-space, part of a word
            next_in_word  = 1'b1;
            next_word_len = word_len + 4'd1;
            next_in_idx   = in_idx + 6'd1;
          end else begin
            // Space or null: word break or spacer
            if (in_word) begin
              // End of a word, go compare its length
              next_hold_word_len = word_len;
              next_in_word       = 1'b0;
              next_word_len      = 4'd0;
              next_state         = COMPARE;
            end else begin
              // Still outside word, just skip extra spaces
              next_in_idx = in_idx + 6'd1;
            end
          end
        end else begin
          // Reached end of string
          if (in_word) begin
            // Last word terminates at end
            next_hold_word_len = word_len;
            next_in_word       = 1'b0;
            next_word_len      = 4'd0;
            next_state         = COMPARE;
          end else begin
            // No trailing word; we are done
            next_state    = DONE;
          end
        end
      end

      COMPARE: begin
        // Decide whether to keep or drop the word based on length K
        if (hold_word_len == {1'b0,K}) begin
          // Drop this word: do not modify str_out
          // Move to PARSE to continue
          next_state = (in_idx < 6'd32) ? PARSE : DONE;
        end else begin
          // Keep this word: go to BUILD_OUT to append characters
          next_state = BUILD_OUT;
          // Rewind index to the start position of this word to copy chars
          // The word length is hold_word_len; in_idx currently at first char after word end
          // so start index is in_idx - hold_word_len - 1 (because we advanced past delimiter)
          if (in_idx >= hold_word_len + 1) begin
            next_in_idx = in_idx - hold_word_len - 1;
          end else begin
            next_in_idx = 6'd0;
          end
        end
      end

      BUILD_OUT: begin
        // Append kept word characters to output, respecting spaces rules
        // If this is the first kept word, no leading space
        // Else insert a single space before new word
        integer i;
        reg [7:0] ch;

        // Insert leading space if not first word and word has non-zero length
        if (hold_word_len != 4'd0) begin
          if (has_prev_word) begin
            if (out_idx < 6'd32) begin
              str_out[255 - out_idx*8 -: 8] = 8'h20;
              next_out_idx = out_idx + 6'd1;
            end
          end
        end

        // Copy the word characters from original string
        for (i = 0; i < 8; i = i + 1) begin
          if (i < hold_word_len && next_out_idx < 6'd32) begin
            ch = str_in[255 - (next_in_idx + i)*8 -: 8];
            str_out[255 - next_out_idx*8 -: 8] = ch;
            next_out_idx = next_out_idx + 6'd1;
          end
        end

        // Mark that we now have at least one word in output if this word was non-empty
        if (hold_word_len != 4'd0) begin
          next_has_prev_word = 1'b1;
        end

        // Advance in_idx to position after the word (originally at start index)
        next_in_idx   = next_in_idx + hold_word_len + 6'd1; // skip word plus delimiter
        next_state    = (next_in_idx < 6'd32) ? PARSE : DONE;
      end

      DONE: begin
        next_done_int = 1'b1;
        if (!start) begin
          // Wait until start deasserted before going IDLE
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase

    // Clear output when starting a new operation from IDLE with start
    if (state == IDLE && start) begin
      // blocking assignment is safe in comb; sequential block holds new value next cycle
      str_out = 256'd0;
    end
  end

endmodule