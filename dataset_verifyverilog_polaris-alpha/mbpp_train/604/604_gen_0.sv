module reverse_words(
  input  clk,
  input  rst_n,
  input  start,
  input  [127:0] str,
  output reg [127:0] reversed_str,
  output reg done
);

  // FSM states
  localparam IDLE           = 3'd0;
  localparam INIT           = 3'd1;
  localparam SKIP_LEADING   = 3'd2;
  localparam FIND_WORD      = 3'd3;
  localparam COPY_WORD      = 3'd4;
  localparam SKIP_GAP       = 3'd5;
  localparam DONE_STATE     = 3'd6;

  reg [2:0] state, next_state;

  // index into input string: 0..15 (LSB first)
  reg [4:0] in_idx;
  reg [4:0] next_in_idx;

  // next output index
  reg [4:0] out_idx;
  reg [4:0] next_out_idx;

  // current word start index in input
  reg [4:0] word_start;
  reg [4:0] next_word_start;

  // current word length
  reg [3:0] word_len;
  reg [3:0] next_word_len;

  // remaining characters of current word to copy
  reg [3:0] copy_rem;
  reg [3:0] next_copy_rem;

  // number of words found (max 4, track up to 7 safely with 3 bits)
  reg [2:0] word_count;
  reg [2:0] next_word_count;

  // latched input string
  reg [127:0] str_reg;
  reg [127:0] next_reversed_str;

  // helper: get character at given index (LSB-first, 8 bits per char)
  function automatic [7:0] get_char;
    input [127:0] bus;
    input [4:0]   idx;
    begin
      get_char = bus[(idx*8) +: 8];
    end
  endfunction

  // helper: set character at given index
  function automatic [127:0] set_char;
    input [127:0] bus;
    input [4:0]   idx;
    input [7:0]   ch;
    reg   [127:0] tmp;
    begin
      tmp = bus;
      tmp[(idx*8) +: 8] = ch;
      set_char = tmp;
    end
  endfunction

  // combinational next-state / next-data logic
  always @* begin
    // defaults: hold values
    next_state        = state;
    next_in_idx       = in_idx;
    next_out_idx      = out_idx;
    next_word_start   = word_start;
    next_word_len     = word_len;
    next_copy_rem     = copy_rem;
    next_word_count   = word_count;
    next_reversed_str = reversed_str;
    done              = 1'b0;

    case (state)
      IDLE: begin
        if (start) begin
          // latch input, clear outputs/indices in sequential block
          next_state = INIT;
        end
      end

      INIT: begin
        // Initialize scanning from index 0, clear output and counters
        next_in_idx       = 5'd0;
        next_out_idx      = 5'd0;
        next_word_count   = 3'd0;
        next_word_len     = 4'd0;
        next_copy_rem     = 4'd0;
        next_word_start   = 5'd0;
        // fully pad output with spaces
        next_reversed_str = {16{8'h20}};
        next_state        = SKIP_LEADING;
      end

      SKIP_LEADING: begin
        if (in_idx >= 5'd16) begin
          // all spaces or empty -> we're done, output already padded
          next_state = DONE_STATE;
        end else begin
          if (get_char(str_reg, in_idx) == 8'h20) begin
            // skip leading spaces
            next_in_idx = in_idx + 5'd1;
          end else begin
            // first non-space: start of first word
            next_word_start = in_idx;
            next_word_len   = 4'd1;
            next_in_idx     = in_idx + 5'd1;
            next_state      = FIND_WORD;
          end
        end
      end

      FIND_WORD: begin
        if (in_idx >= 5'd16) begin
          // reached end of string: finalize last word
          if (word_len != 4'd0) begin
            // schedule copy of this word
            next_copy_rem   = word_len;
            next_state      = COPY_WORD;
            next_word_count = word_count + 3'd1;
          end else begin
            next_state = DONE_STATE;
          end
        end else begin
          if (get_char(str_reg, in_idx) == 8'h20) begin
            // end of word at in_idx-1
            if (word_len != 4'd0) begin
              // valid word completed
              next_copy_rem   = word_len;
              next_state      = COPY_WORD;
              next_word_count = word_count + 3'd1;
              // in_idx currently at space; next state decides on gap/next word
            end else begin
              // shouldn't happen; just skip
              next_in_idx = in_idx + 5'd1;
            end
          end else begin
            // still inside word
            next_word_len = word_len + 4'd1;
            next_in_idx   = in_idx + 5'd1;
          end
        end
      end

      COPY_WORD: begin
        if (copy_rem != 4'd0) begin
          // compute source char index: word_start + (word_len - copy_rem)
          // copy forward to output (words will appear in discovery order now)
          // To get reversed word order overall, we instead place this word
          // starting from current out_idx, but words are collected in order;
          // we'll build in-place in reverse order by emitting a space before
          // existing words only when out_idx != 0.
          // Here implement straightforward streaming:

          // insert leading space if this is not the first output word
          if ((word_count > 3'd0) && (copy_rem == word_len)) begin
            if (out_idx < 5'd16) begin
              next_reversed_str = set_char(next_reversed_str, out_idx, 8'h20);
              next_out_idx      = out_idx + 5'd1;
            end
          end

          if (out_idx < 5'd16) begin
            // source index
            // src = word_start + (word_len - copy_rem)
            // ensure within range
            // compute
            // note: use intermediate integer via concatenation
            // SystemVerilog allows this arithmetic directly
            next_reversed_str = set_char(
              next_reversed_str,
              out_idx,
              get_char(str_reg, word_start + (word_len - copy_rem))
            );
            next_out_idx = out_idx + 5'd1;
          end

          next_copy_rem = copy_rem - 4'd1;
        end else begin
          // finished copying one word.
          // If hit max words (4), or input ended, we are done;
          // else if last char observed was space, skip gaps then next word.
          if (in_idx >= 5'd16) begin
            next_state = DONE_STATE;
          end else begin
            // Last read char that caused word end is at in_idx (space).
            next_state = SKIP_GAP;
          end
        end
      end

      SKIP_GAP: begin
        if (word_count >= 3'd4) begin
          // limit to 4 words
          next_state = DONE_STATE;
        end else if (in_idx >= 5'd16) begin
          next_state = DONE_STATE;
        end else begin
          if (get_char(str_reg, in_idx) == 8'h20) begin
            // skip multiple spaces
            next_in_idx = in_idx + 5'd1;
          end else begin
            // start of next word
            next_word_start = in_idx;
            next_word_len   = 4'd1;
            next_in_idx     = in_idx + 5'd1;
            next_state      = FIND_WORD;
          end
        end
      end

      DONE_STATE: begin
        done = 1'b1;
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      in_idx        <= 5'd0;
      out_idx       <= 5'd0;
      word_start    <= 5'd0;
      word_len      <= 4'd0;
      copy_rem      <= 4'd0;
      word_count    <= 3'd0;
      reversed_str  <= {16{8'h20}};
      str_reg       <= 128'd0;
    end else begin
      state        <= next_state;
      in_idx       <= next_in_idx;
      out_idx      <= next_out_idx;
      word_start   <= next_word_start;
      word_len     <= next_word_len;
      copy_rem     <= next_copy_rem;
      word_count   <= next_word_count;
      reversed_str <= next_reversed_str;
      if (state == IDLE && start) begin
        str_reg <= str;
      end
    end
  end

endmodule