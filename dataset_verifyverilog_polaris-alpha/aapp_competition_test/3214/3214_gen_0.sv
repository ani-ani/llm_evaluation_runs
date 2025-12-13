module typo_checker(
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input word_end,
  output reg done,
  output reg [15:0] matches [15:0][15:0]
);

  // Storage for up to 16 words, each up to 8 chars (64 bits per word)
  reg [7:0] word_mem [0:15][0:7];
  reg [3:0] word_len [0:15];
  reg [3:0] word_count;

  // Input control
  reg [3:0] cur_word_idx;
  reg [2:0] cur_char_idx;
  reg end_of_input; // set when *** marker detected

  // FSM states
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_INPUT     = 3'd1,
    S_WAIT_START= 3'd2,
    S_PREPARE   = 3'd3,
    S_COMPARE   = 3'd4,
    S_DONE      = 3'd5
  } state_t;

  state_t state, next_state;

  // Pair indices for comparison
  reg [3:0] i_idx, j_idx;

  // Latency counter after start
  reg [4:0] latency_cnt; // enough for >=16 cycles

  // ------------------------------------------------------------------
  // Sequential state, counters, and storage update
  // ------------------------------------------------------------------
  integer x;
  integer y;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= S_IDLE;
      word_count   <= 4'd0;
      cur_word_idx <= 4'd0;
      cur_char_idx <= 3'd0;
      end_of_input <= 1'b0;
      done         <= 1'b0;
      i_idx        <= 4'd0;
      j_idx        <= 4'd1;
      latency_cnt  <= 5'd0;
      // clear word_len and matches
      for (x = 0; x < 16; x = x + 1) begin
        word_len[x] <= 4'd0;
        for (y = 0; y < 16; y = y + 1) begin
          matches[x][y] <= 16'd0;
        end
      end
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done         <= 1'b0;
          end_of_input <= 1'b0;
          word_count   <= 4'd0;
          cur_word_idx <= 4'd0;
          cur_char_idx <= 3'd0;
          i_idx        <= 4'd0;
          j_idx        <= 4'd1;
          latency_cnt  <= 5'd0;
          // Clear storage and matches on entry
          for (x = 0; x < 16; x = x + 1) begin
            word_len[x] <= 4'd0;
            for (y = 0; y < 16; y = y + 1) begin
              matches[x][y] <= 16'd0;
            end
          end
        end

        S_INPUT: begin
          done <= 1'b0;
          // Handle word input until *** marker
          if (word_end) begin
            if (char_in == 8'd0 && cur_char_idx == 3'd0) begin
              // Detected *** marker as "empty" word with zero char; mark end
              end_of_input <= 1'b1;
              // Do not store this marker as a word
            end else begin
              // Finish current word
              word_len[cur_word_idx] <= cur_char_idx + (char_in != 8'd0 ? 1'b1 : 1'b0);
              if (char_in != 8'd0 && cur_char_idx < 3'd8) begin
                word_mem[cur_word_idx][cur_char_idx] <= char_in;
              end
              if (word_count < 4'd16) begin
                word_count <= word_count + 1'b1;
              end
              if (cur_word_idx < 4'd15) begin
                cur_word_idx <= cur_word_idx + 1'b1;
              end
              cur_char_idx <= 3'd0;
            end
          end else if (!end_of_input) begin
            // Accumulate characters of current word (up to 8 chars)
            if (cur_char_idx < 3'd8) begin
              word_mem[cur_word_idx][cur_char_idx] <= char_in;
              cur_char_idx <= cur_char_idx + 1'b1;
            end
          end
        end

        S_WAIT_START: begin
          done <= 1'b0;
          // hold all values; wait for start
        end

        S_PREPARE: begin
          done        <= 1'b0;
          latency_cnt <= 5'd0;
          i_idx       <= 4'd0;
          j_idx       <= 4'd1;
          // matches already cleared in IDLE or previous logic if needed
        end

        S_COMPARE: begin
          done <= 1'b0;
          // Enforce 16-cycle latency from start
          if (latency_cnt < 5'd16) begin
            latency_cnt <= latency_cnt + 1'b1;
          end

          // Perform one pair comparison per cycle over all i<j
          if (word_count > 1) begin
            // Only compare valid indices
            if (i_idx < word_count && j_idx < word_count) begin
              if (similar_single_edit(word_mem[i_idx], word_len[i_idx],
                                      word_mem[j_idx], word_len[j_idx])) begin
                matches[i_idx][j_idx][0] <= 1'b1; // mark match bit 0 as flag
              end
            end

            // Advance pair indices
            if (j_idx + 1 < word_count) begin
              j_idx <= j_idx + 1'b1;
            end else begin
              if (i_idx + 2 < word_count) begin
                i_idx <= i_idx + 1'b1;
                j_idx <= i_idx + 2; // next j > i
              end
            end
          end
        end

        S_DONE: begin
          done <= 1'b1;
        end

        default: begin
          // should not occur
        end
      endcase
    end
  end

  // ------------------------------------------------------------------
  // Next-state logic
  // ------------------------------------------------------------------
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        next_state = S_INPUT;
      end

      S_INPUT: begin
        if (end_of_input) begin
          next_state = S_WAIT_START;
        end else begin
          next_state = S_INPUT;
        end
      end

      S_WAIT_START: begin
        if (start) begin
          next_state = S_PREPARE;
        end else begin
          next_state = S_WAIT_START;
        end
      end

      S_PREPARE: begin
        next_state = S_COMPARE;
      end

      S_COMPARE: begin
        // Move to DONE when latency satisfied and all pairs processed
        if (latency_cnt >= 5'd16) begin
          if (word_count <= 1) begin
            next_state = S_DONE;
          end else if (i_idx + 2 >= word_count && j_idx + 1 >= word_count) begin
            next_state = S_DONE;
          end else begin
            next_state = S_COMPARE;
          end
        end else begin
          next_state = S_COMPARE;
        end
      end

      S_DONE: begin
        // Remain DONE until reset
        next_state = S_DONE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  // ------------------------------------------------------------------
  // Similarity check: single edit distance = 1
  // Includes: insert, delete, replace, adjacent transpose
  // wordA, wordB: 8x8-bit arrays; lenA/lenB: 0-8
  // ------------------------------------------------------------------
  function automatic bit similar_single_edit(
    input reg [7:0] wA [0:7],
    input [3:0] lenA,
    input reg [7:0] wB [0:7],
    input [3:0] lenB
  );
    int i;

    // Internal helper for replace distance 1
    function automatic bit is_replace1(
      input reg [7:0] a [0:7],
      input reg [7:0] b [0:7],
      input [3:0] len
    );
      int k;
      int diff;
      begin
        diff = 0;
        for (k = 0; k < len; k = k + 1) begin
          if (a[k] != b[k]) diff = diff + 1;
        end
        is_replace1 = (diff == 1);
      end
    endfunction

    // Internal helper for insert/delete (len diff = 1)
    function automatic bit is_insert_delete1(
      input reg [7:0] s [0:7],
      input [3:0] lenS,
      input reg [7:0] l [0:7],
      input [3:0] lenL
    );
      int i_s, i_l;
      int diff;
      begin
        if (lenL != lenS + 1) begin
          is_insert_delete1 = 1'b0;
        end else begin
          i_s = 0;
          i_l = 0;
          diff = 0;
          while (i_s < lenS && i_l < lenL) begin
            if (s[i_s] == l[i_l]) begin
              i_s = i_s + 1;
              i_l = i_l + 1;
            end else begin
              diff = diff + 1;
              i_l = i_l + 1; // skip one char in longer string
              if (diff > 1) begin
                i_s = lenS; // break
                i_l = lenL;
              end
            end
          end
          // remaining chars in longer string count as at most 1 extra
          if (i_l < lenL) diff = diff + (lenL - i_l);
          is_insert_delete1 = (diff == 1);
        end
      end
    endfunction

    // Internal helper for transpose (len equal)
    function automatic bit is_transpose1(
      input reg [7:0] a [0:7],
      input reg [7:0] b [0:7],
      input [3:0] len
    );
      int k;
      int pos;
      int diff;
      begin
        diff = 0;
        pos = -1;
        for (k = 0; k < len; k = k + 1) begin
          if (a[k] != b[k]) begin
            diff = diff + 1;
            if (pos < 0) pos = k;
          end
        end
        if (diff != 2) begin
          is_transpose1 = 1'b0;
        end else if (pos < 0 || pos + 1 >= len) begin
          is_transpose1 = 1'b0;
        end else begin
          // Check swap at pos/pos+1
          if (a[pos]   == b[pos+1] &&
              a[pos+1] == b[pos]   ) begin
            // and all others already matched by construction
            is_transpose1 = 1'b1;
          end else begin
            is_transpose1 = 1'b0;
          end
        end
      end
    endfunction

    begin
      // Default
      similar_single_edit = 1'b0;

      // Ignore if any length is 0
      if (lenA == 0 || lenB == 0) begin
        similar_single_edit = 1'b0;
      end else if (lenA == lenB) begin
        // Replace or transpose
        if (is_replace1(wA, wB, lenA)) begin
          similar_single_edit = 1'b1;
        end else if (is_transpose1(wA, wB, lenA)) begin
          similar_single_edit = 1'b1;
        end
      end else if (lenA + 1 == lenB) begin
        // A shorter, B longer
        if (is_insert_delete1(wA, lenA, wB, lenB)) begin
          similar_single_edit = 1'b1;
        end
      end else if (lenB + 1 == lenA) begin
        // B shorter, A longer
        if (is_insert_delete1(wB, lenB, wA, lenA)) begin
          similar_single_edit = 1'b1;
        end
      end
    end
  endfunction

endmodule