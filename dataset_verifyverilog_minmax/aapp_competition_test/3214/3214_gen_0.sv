module typo_checker(
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input word_end,
  output reg done,
  output reg [15:0] matches [15:0][15:0]
);

  // Internal storage: up to 16 words, 8 chars each, 8-bit ASCII
  reg [7:0] words [0:15][0:7];
  reg [3:0] wlen [0:15];
  reg [3:0] word_count;
  reg [7:0] char_buf [0:7];
  reg [2:0] char_idx;
  reg [4:0] pair_i, pair_j, next_pair_i, next_pair_j;
  reg [3:0] compare_counter;  // 4 bits to count 0..15
  reg [3:0] i_cur, j_cur;
  reg [3:0] i_ahead, j_ahead;
  reg [4:0] pi, pj;
  reg started_r;
  reg in_progress;
  reg cmp_done;

  // FSM states
  reg [1:0] state, next_state;
  localparam S_IDLE   = 2'd0;
  localparam S_LOAD   = 2'd1;
  localparam S_COMP   = 2'd2;
  localparam S_DONE   = 2'd3;

  // State update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Input edge detect for start
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      started_r <= 1'b0;
    end else begin
      started_r <= start;
    end
  end
  wire start_posedge = start && !started_r;

  // Main FSM and control logic
  integer k;
  always @(*) begin
    // Defaults
    next_state = state;
    in_progress = 1'b0;
    compare_counter = 4'd0;
    done = 1'b0;
    cmp_done = 1'b0;
    // Pointers for current pair
    i_cur = 4'd0;
    j_cur = 4'd0;
    i_ahead = 4'd0;
    j_ahead = 4'd0;
    pi = 5'd0;
    pj = 5'd0;
    // Defaults for comparison pointers
    // They will be set per state below
    case (state)
      S_IDLE: begin
        // Reset data paths; wait for start
        if (start_posedge) begin
          next_state = S_LOAD;
        end
      end
      S_LOAD: begin
        in_progress = 1'b1;
        // When we detect the *** marker, move to comparison
        if (word_end && (char_in === 8'h00)) begin
          next_state = S_COMP;
        end
      end
      S_COMP: begin
        in_progress = 1'b1;
        compare_counter = 4'd1; // we process one pair per cycle
        i_cur = pair_i;
        j_cur = pair_j;
        // Ahead pointers for current pair
        i_ahead = (pair_i < (word_count - 1)) ? (pair_i + 1) : pair_i;
        j_ahead = (pair_j < (word_count - 1)) ? (pair_j + 1) : pair_j;
        pi = next_pair_i;
        pj = next_pair_j;
        if (cmp_done) begin
          next_state = S_DONE;
        end
      end
      S_DONE: begin
        done = 1'b1;
        // Allow restart
        if (start_posedge) begin
          next_state = S_LOAD;
        end else begin
          next_state = S_DONE;
        end
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Load word logic and pointer updates
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset memory and counters
      for (k = 0; k < 16; k = k + 1) begin
        words[k][0] <= 8'h00; words[k][1] <= 8'h00; words[k][2] <= 8'h00; words[k][3] <= 8'h00;
        words[k][4] <= 8'h00; words[k][5] <= 8'h00; words[k][6] <= 8'h00; words[k][7] <= 8'h00;
        wlen[k] <= 4'd0;
        matches[k][0] <= 1'b0; matches[k][1] <= 1'b0; matches[k][2] <= 1'b0; matches[k][3] <= 1'b0;
        matches[k][4] <= 1'b0; matches[k][5] <= 1'b0; matches[k][6] <= 1'b0; matches[k][7] <= 1'b0;
        matches[k][8] <= 1'b0; matches[k][9] <= 1'b0; matches[k][10] <= 1'b0; matches[k][11] <= 1'b0;
        matches[k][12] <= 1'b0; matches[k][13] <= 1'b0; matches[k][14] <= 1'b0; matches[k][15] <= 1'b0;
      end
      word_count <= 4'd0;
      char_idx <= 3'd0;
      pair_i <= 5'd0;
      pair_j <= 5'd1;
      next_pair_i <= 5'd0;
      next_pair_j <= 5'd1;
      cmp_done <= 1'b0;
    end else begin
      // Defaults
      cmp_done <= 1'b0;

      case (state)
        S_IDLE: begin
          // Initialize for a new run
          word_count <= 4'd0;
          char_idx <= 3'd0;
          pair_i <= 5'd0;
          pair_j <= 5'd1;
          next_pair_i <= 5'd0;
          next_pair_j <= 5'd1;
          // Clear storage for first word to be written
        end

        S_LOAD: begin
          if (word_end) begin
            if (char_in === 8'h00) begin
              // Terminate loading. Prepare for comparison
              // word_count already set to the number of stored words
              // Initialize pair pointers to the first pair (0,1)
              pair_i <= 5'd0;
              pair_j <= 5'd1;
              // Compute next pair after (0,1) to set pipeline for next cycle
              if (1 < (word_count - 1)) begin
                next_pair_i <= 5'd0;
                next_pair_j <= 5'd2;
              end else begin
                if (word_count >= 2) begin
                  next_pair_i <= 5'd1;
                  next_pair_j <= 5'd2;
                end else begin
                  next_pair_i <= 5'd0;
                  next_pair_j <= 5'd1;
                end
              end
            end else begin
              // Store the completed word
              if (char_idx > 0) begin
                words[word_count][0] <= char_buf[0];
                words[word_count][1] <= char_buf[1];
                words[word_count][2] <= char_buf[2];
                words[word_count][3] <= char_buf[3];
                words[word_count][4] <= char_buf[4];
                words[word_count][5] <= char_buf[5];
                words[word_count][6] <= char_buf[6];
                words[word_count][7] <= char_buf[7];
                wlen[word_count] <= char_idx;
                word_count <= (word_count < 4'd15) ? (word_count + 4'd1) : word_count;
              end
              char_idx <= 3'd0;
              // Prepare buffer to start next word
            end
          end else begin
            // Accumulate characters for current word
            if (char_idx < 3'd8) begin
              char_buf[char_idx] <= char_in;
              char_idx <= char_idx + 3'd1;
            end
          end
        end

        S_COMP: begin
          // Compute one pair per cycle, then advance pointers
          if ((pair_i < word_count) && (pair_j < word_count)) begin
            // Perform single-edit-distance-1 check
            if (is_similar_single_edit(words[pair_i], wlen[pair_i], words[pair_j], wlen[pair_j])) begin
              matches[pair_i][pair_j] <= 1'b1;
              matches[pair_j][pair_i] <= 1'b1; // symmetry if desired
            end
            // Advance to next pair
            if (pair_j < (word_count - 1)) begin
              pair_j <= pair_j + 5'd1;
            end else begin
              pair_i <= pair_i + 5'd1;
              pair_j <= 5'd0;
            end
            // Update next_pair_i/j for next cycle
            if (pair_j < (word_count - 1)) begin
              next_pair_i <= pair_i;
              next_pair_j <= pair_j + 5'd1;
            end else begin
              if (pair_i < (word_count - 1)) begin
                next_pair_i <= pair_i + 5'd1;
                next_pair_j <= 5'd0;
              end else begin
                // No more pairs after this one
                cmp_done <= 1'b1;
                next_pair_i <= pair_i;
                next_pair_j <= pair_j;
              end
            end
          end else begin
            cmp_done <= 1'b1;
            next_pair_i <= pair_i;
            next_pair_j <= pair_j;
          end
        end

        S_DONE: begin
          // Hold done; allow restart via start_posedge
          // If restarted, S_LOAD will clear matches anew
          if (start_posedge) begin
            // Clear output matrix for new run
            for (k = 0; k < 16; k = k + 1) begin
              matches[k][0] <= 1'b0; matches[k][1] <= 1'b0; matches[k][2] <= 1'b0; matches[k][3] <= 1'b0;
              matches[k][4] <= 1'b0; matches[k][5] <= 1'b0; matches[k][6] <= 1'b0; matches[k][7] <= 1'b0;
              matches[k][8] <= 1'b0; matches[k][9] <= 1'b0; matches[k][10] <= 1'b0; matches[k][11] <= 1'b0;
              matches[k][12] <= 1'b0; matches[k][13] <= 1'b0; matches[k][14] <= 1'b0; matches[k][15] <= 1'b0;
            end
            word_count <= 4'd0;
            char_idx <= 3'd0;
            pair_i <= 5'd0;
            pair_j <= 5'd1;
            next_pair_i <= 5'd0;
            next_pair_j <= 5'd1;
            cmp_done <= 1'b0;
          end
        end

        default: ;
      endcase
    end
  end

  // Single-edit similarity check function (combinational)
  // Returns 1 if two words differ by at most one edit: delete, insert, replace, or transpose.
  function [0:0] is_similar_single_edit;
    input [7:0] a [0:7];
    input [3:0] la;
    input [7:0] b [0:7];
    input [3:0] lb;
    reg [3:0] i, j;
    reg mismatch, extra_a, extra_b, trans_ok;
    reg [7:0] ac, bc;
    begin
      is_similar_single_edit = 1'b0;
      // Quick reject by length difference > 1
      if ((la > (lb + 4'd1)) || (lb > (la + 4'd1))) begin
        is_similar_single_edit = 1'b0;
        return;
      end
      // Same length: replacement or transpose check
      if (la === lb) begin
        mismatch = 1'b0;
        extra_a = 1'b0;
        extra_b = 1'b0;
        for (i = 4'd0; i < 4'd8; i = i + 4'd1) begin
          if (i >= la) break;
          if (a[i] !== b[i]) begin
            if (mismatch) begin
              // more than one mismatch -> not a single replace/transpose
              is_similar_single_edit = 1'b0;
              return;
            end else begin
              mismatch = 1'b1;
              // Check for adjacent transpose
              if ((i + 4'd1) < la) begin
                if ((a[i] === b[i+1]) && (a[i+1] === b[i])) begin
                  trans_ok = 1'b1;
                  // Skip next character on both sides
                  // i will increment by 1, so we add an extra skip by i+2
                  // We accomplish this by advancing i here and relying on loop +1
                  i = i + 4'd1; // skip next in loop (loop will add +1)
                end else begin
                  trans_ok = 1'b0;
                end
              end else begin
                trans_ok = 1'b0;
              end
              if (trans_ok) begin
                // continue with trans_ok set; on loop increment, we effectively move to i+2
              end else begin
                // Remember mismatch seen; continue to check rest match
                // But we can't set i ahead; just flag mismatch and continue
              end
            end
          end
        end
        // If no mismatch: equal strings => similar
        if (!mismatch) begin
          is_similar_single_edit = 1'b1;
          return;
        end
        // If mismatch seen and trans_ok set, then similar by transpose
        // else, if mismatch seen only once and rest matched, similar by replace
        // The logic above sets trans_ok; else if not trans and mismatch occurred only once, it's replace.
        // However, if mismatch and we didn't break early, we need to verify the rest matched.
        // We'll re-scan to ensure only one mismatch (or the matched-by-trans case handled above)
        mismatch = 1'b0;
        for (i = 4'd0; i < 4'd8; i = i + 4'd1) begin
          if (i >= la) break;
          if (a[i] !== b[i]) begin
            if (mismatch) begin
              is_similar_single_edit = 1'b0;
              return;
            end else begin
              mismatch = 1'b1;
              // Check for possible adjacent transposition skipping one pair
              if ((i + 4'd1) < la) begin
                if ((a[i] === b[i+1]) && (a[i+1] === b[i])) begin
                  // valid transpose
                  is_similar_single_edit = 1'b1;
                  return;
                end
              end
            end
          end
        end
        // If reached here and mismatch is 1, it's a single replacement
        if (mismatch) begin
          is_similar_single_edit = 1'b1;
        end else begin
          is_similar_single_edit = 1'b1; // identical
        end
        return;
      end

      // Length differ by 1: deletion from A vs insertion into B
      if (la === (lb + 4'd1)) begin
        // Check deletion in A
        i = 4'd0; j = 4'd0;
        extra_a = 1'b0;
        while (i < la && j < lb) begin
          if (a[i] === b[j]) begin
            i = i + 4'd1;
            j = j + 4'd1;
          end else begin
            if (extra_a) begin
              extra_a = 1'b0; // more than one extra in A
              break;
            end else begin
              extra_a = 1'b1; // allow one deletion in A
              i = i + 4'd1;   // skip char in A
              // j stays
            end
          end
        end
        // If we exit loop, allow the extra char to be at the end
        if (j == lb) begin
          // ok if i is la or i == la-1
          if (i == la || i == (la - 4'd1)) begin
            is_similar_single_edit = 1'b1;
            return;
          end
        end
        // If not ok, reject
        is_similar_single_edit = 1'b0;
        return;
      end

      if (lb === (la + 4'd1)) begin
        // Check deletion in B (equivalent to insertion in A)
        i = 4'd0; j = 4'd0;
        extra_b = 1'b0;
        while (i < la && j < lb) begin
          if (a[i] === b[j]) begin
            i = i + 4'd1;
            j = j + 4'd1;
          end else begin
            if (extra_b) begin
              extra_b = 1'b0;
              break;
            end else begin
              extra_b = 1'b1;
              j = j + 4'd1; // skip char in B
              // i stays
            end
          end
        end
        if (i == la) begin
          if (j == lb || j == (lb - 4'd1)) begin
            is_similar_single_edit = 1'b1;
            return;
          end
        end
        is_similar_single_edit = 1'b0;
        return;
      end

      // Lengths equal or differ by 1 handled; if not, already rejected
      is_similar_single_edit = 1'b0;
    end
  endfunction

endmodule