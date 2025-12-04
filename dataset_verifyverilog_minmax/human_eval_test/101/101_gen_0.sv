module word_splitter (
  input  clk,
  input  rst_n,
  input  start,
  input  [127:0] ascii_str,
  output reg [511:0] words,
  output reg [3:0] word_count,
  output reg done
);

  // FSM states
  localparam ST_IDLE      = 2'b00;
  localparam ST_PROCESS   = 2'b01;
  localparam ST_DONE      = 2'b10;

  // Internal signals
  reg [1:0] state, next_state;
  reg [4:0] idx;              // 0..15
  reg [4:0] idx_next;
  reg [4:0] next_i;           // next index to process (1..16, 16 = finished)
  reg start_pipe;

  reg [3:0] curr_word_count;  // 0..4
  reg [3:0] next_word_count;
  reg [6:0] curr_word_ptr;    // 0..127 (byte position within the 128-bit word)
  reg [6:0] next_word_ptr;
  reg [127:0] curr_words [3:0]; // up to 4 words, 16 chars each
  reg [127:0] next_words [3:0];
  reg       curr_word_active;    // currently writing into a word
  reg       next_word_active;
  reg [4:0] curr_char_cnt;       // chars consumed in current word
  reg [4:0] next_char_cnt;
  reg       max_words_reached;
  reg       next_max_reached;
  reg [7:0] ch;                  // current char being processed
  reg       delim;
  reg       non_delim;
  reg       at_start;            // idx == 0
  reg       last_char_delim;     // previous char was a delimiter
  reg       next_last_delim;

  integer i;

  // Character classification
  always_comb begin
    ch      = ascii_str[(127 - (idx * 8)) -: 8];
    delim   = (ch == 8'h20) || (ch == 8'h2C);  // space or comma
    non_delim = ~delim;
    at_start = (idx == 5'd0);
  end

  // Next-state logic (combinational except where noted)
  always_comb begin
    next_state      = state;
    idx_next        = idx;
    next_i          = idx + 1;
    next_word_count = curr_word_count;
    next_word_ptr   = curr_word_ptr;
    next_last_delim = last_char_delim;
    next_word_active= curr_word_active;
    next_char_cnt   = curr_char_cnt;
    next_max_reached= max_words_reached;

    for (int k=0; k<4; k++) next_words[k] = curr_words[k];

    case (state)
      ST_IDLE: begin
        // Latch inputs on start
        if (start) begin
          next_state = ST_PROCESS;
          idx_next   = 5'd0;
          next_i     = 5'd1;
        end else begin
          next_state = ST_IDLE;
          idx_next   = 5'd0;
          next_i     = 'd0;
        end
        // Clear everything when in IDLE
        next_word_count = 4'd0;
        next_word_ptr   = 7'd0;
        next_last_delim = 1'b0;
        next_word_active= 1'b0;
        next_char_cnt   = 5'd0;
        next_max_reached= 1'b0;
        for (int k=0; k<4; k++) next_words[k] = 128'd0;
      end

      ST_PROCESS: begin
        // Deassert done
        next_state = ST_PROCESS;

        if (non_delim && !max_words_reached) begin
          // Start a new word only if coming from a delimiter (or at position 0)
          if (!curr_word_active || last_char_delim) begin
            next_word_active = 1'b1;
            next_char_cnt    = 5'd1;
            next_word_ptr    = 7'd0;
            // Initialize new word with this char, pad the rest with 0
            next_words[curr_word_count] = {120'h0, ch};
          end else begin
            // Append char to current word
            next_word_active = 1'b1;
            next_char_cnt    = curr_char_cnt + 1;
            next_word_ptr    = curr_word_ptr + 8;
            if (curr_char_cnt < 5'd15) begin
              next_words[curr_word_count] = {curr_words[curr_word_count][119:0], ch};
            end
          end
          next_last_delim = 1'b0;
        end else if (delim) begin
          // End current word on delimiter
          if (curr_word_active) begin
            next_word_active = 1'b0;
            // Increment count only if a word was actually started
            if (curr_word_count < 4'd4) begin
              next_word_count = curr_word_count + 1;
            end
            // Check if we just filled 4 words
            if ((curr_word_count + 1) >= 4) begin
              next_max_reached = 1'b1;
            end
          end else begin
            next_word_active = curr_word_active;
          end
          next_last_delim = 1'b1;
        end else begin
          // non_delim but max words reached: just consume characters
          next_last_delim = last_char_delim;
          next_word_active= curr_word_active;
        end

        // Advance index each cycle
        idx_next = idx + 1;
        next_i   = idx + 2;

        // If we've processed all 16 chars, go to DONE
        if (idx == 5'd15) begin
          // Finalize if a word is active
          if (curr_word_active) begin
            if (curr_word_count < 4'd4) begin
              next_word_count = curr_word_count + 1;
            end
            if ((curr_word_count + 1) >= 4) begin
              next_max_reached = 1'b1;
            end
          end
          next_state = ST_DONE;
          idx_next   = 5'd0;
          next_i     = 5'd0;
        end
      end

      ST_DONE: begin
        next_state = ST_IDLE;
        idx_next   = 5'd0;
        next_i     = 5'd0;
        // Keep everything held until returning to IDLE
        for (int k=0; k<4; k++) next_words[k] = curr_words[k];
        next_word_count = curr_word_count;
        next_word_ptr   = curr_word_ptr;
        next_last_delim = last_char_delim;
        next_word_active= curr_word_active;
        next_char_cnt   = curr_char_cnt;
        next_max_reached= max_words_reached;
      end

      default: begin
        next_state = ST_IDLE;
        idx_next   = 5'd0;
        next_i     = 5'd0;
        for (int k=0; k<4; k++) next_words[k] = 128'd0;
        next_word_count = 4'd0;
        next_word_ptr   = 7'd0;
        next_last_delim = 1'b0;
        next_word_active= 1'b0;
        next_char_cnt   = 5'd0;
        next_max_reached= 1'b0;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= ST_IDLE;
      idx   <= 5'd0;
      curr_word_count <= 4'd0;
      curr_word_ptr   <= 7'd0;
      curr_word_active<= 1'b0;
      curr_char_cnt   <= 5'd0;
      max_words_reached<= 1'b0;
      last_char_delim <= 1'b0;
      for (i=0; i<4; i++) curr_words[i] <= 128'd0;
    end else begin
      state <= next_state;
      idx   <= idx_next;
      curr_word_count <= next_word_count;
      curr_word_ptr   <= next_word_ptr;
      curr_word_active<= next_word_active;
      curr_char_cnt   <= next_char_cnt;
      max_words_reached<= next_max_reached;
      last_char_delim <= next_last_delim;
      for (i=0; i<4; i++) curr_words[i] <= next_words[i];
    end
  end

  // Output logic
  always @(*) begin
    done        = (state == ST_DONE);
    words       = {curr_words[3], curr_words[2], curr_words[1], curr_words[0]};
    word_count  = curr_word_count;
  end

endmodule