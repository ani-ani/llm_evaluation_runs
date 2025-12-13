module word_descrambler(
  input clk,
  input rst_n,
  input start,
  input [127:0] scrambled_str,
  input [63:0] dict_words [0:7],
  input [2:0] word_count,
  output reg [127:0] deciphered_str,
  output reg [1:0] status,
  output reg [3:0] output_length
);

  // Parameters
  localparam MAX_IN_LEN   = 16;
  localparam MAX_DICT     = 8;
  localparam MAX_WORD_LEN = 8;
  localparam MAX_SOL      = 4;      // store up to 4 candidate solutions

  localparam ST_IDLE      = 3'd0;
  localparam ST_INIT      = 3'd1;
  localparam ST_TRY_SPLIT = 3'd2;
  localparam ST_EVAL      = 3'd3;
  localparam ST_DONE      = 3'd4;

  // Internal regs
  reg [2:0] state, next_state;

  // Input string buffering as bytes
  reg [7:0] in_chars [0:MAX_IN_LEN-1];
  reg [4:0] in_len;  // 0-16

  // Dictionary decoded bytes and effective lengths
  reg [7:0] dict_char [0:MAX_DICT-1][0:MAX_WORD_LEN-1];
  reg [3:0] dict_len  [0:MAX_DICT-1];

  // Pre-decode control
  reg        load_inputs;
  integer    i,j;

  // Backtracking state for word splits
  // pos: current index in input (0..16)
  // depth: word index count used so far
  reg [4:0] cur_pos;
  reg [3:0] cur_depth;

  // store chosen dict index per depth during current path
  reg [2:0] path_word_idx [0:MAX_IN_LEN-1];
  reg [3:0] path_word_len [0:MAX_IN_LEN-1];

  // iteration over dictionary for trying match at current pos
  reg [2:0] try_dict_idx;
  reg       have_match_candidate;
  reg [2:0] match_dict_idx;
  reg [3:0] match_word_len;

  // control flags
  reg        search_active;
  reg [7:0]  cycle_count;

  // solution storage: each solution is packed characters + length
  reg [127:0] solution_str   [0:MAX_SOL-1];
  reg [3:0]   solution_len   [0:MAX_SOL-1];
  reg [2:0]   solution_count;

  // Temporary combinational for building solution string from path
  reg [127:0] build_str;
  reg [3:0]   build_len;

  // -------------------- Helper tasks/functions --------------------

  // Compute length of 8-byte dictionary word (null-terminated or trailing zeros)
  function automatic [3:0] f_dict_len(input [63:0] w);
    integer k;
    begin
      f_dict_len = 0;
      for (k = 0; k < MAX_WORD_LEN; k = k + 1) begin
        if (w[8*(MAX_WORD_LEN-1-k) +: 8] != 8'd0)
          f_dict_len = f_dict_len + 1;
      end
    end
  endfunction

  // Extract substring from in_chars[start .. start+len-1] into arr
  task automatic t_get_substr(
    input  [4:0] start,
    input  [3:0] len,
    output reg [7:0] sub [0:MAX_WORD_LEN-1]
  );
    integer k;
    begin
      for (k = 0; k < MAX_WORD_LEN; k = k + 1) begin
        if (k < len)
          sub[k] = in_chars[start + k];
        else
          sub[k] = 8'd0;
      end
    end
  endtask

  // Compute letter count signature for inner letters (a-z only, case-sensitive simple mapping)
  task automatic t_inner_sig(
    input  [7:0] arr [0:MAX_WORD_LEN-1],
    input  [3:0] len,
    output reg [3:0] sig [0:25]
  );
    integer k;
    integer idx;
    begin
      for (idx = 0; idx < 26; idx = idx + 1) sig[idx] = 4'd0;
      if (len <= 2) begin
        // no inner letters
      end else begin
        for (k = 1; k < len-1; k = k + 1) begin
          if (arr[k] >= "a" && arr[k] <= "z") begin
            idx = arr[k] - "a";
            if (sig[idx] != 4'hF) // saturate
              sig[idx] = sig[idx] + 1'b1;
          end else if (arr[k] >= "A" && arr[k] <= "Z") begin
            idx = arr[k] - "A";
            if (sig[idx] != 4'hF)
              sig[idx] = sig[idx] + 1'b1;
          end
        end
      end
    end
  endtask

  // Check if substring at cur_pos with candidate dict word matches by rules
  function automatic match_word(
    input [4:0] pos,
    input [7:0] in_chars_local [0:MAX_IN_LEN-1],
    input [3:0] in_len_local,
    input [7:0] dchars [0:MAX_WORD_LEN-1],
    input [3:0] dlen
  );
    reg [7:0] sub [0:MAX_WORD_LEN-1];
    reg [3:0] sig_s [0:25];
    reg [3:0] sig_d [0:25];
    integer k;
    begin
      match_word = 1'b0;
      if (dlen == 0) begin
        match_word = 1'b0;
      end else if (pos + dlen > in_len_local) begin
        match_word = 1'b0;
      end else begin
        // Load substring
        for (k = 0; k < MAX_WORD_LEN; k = k + 1) begin
          if (k < dlen)
            sub[k] = in_chars_local[pos + k];
          else
            sub[k] = 8'd0;
        end
        // Single-letter: exact match
        if (dlen == 1) begin
          if (sub[0] == dchars[0])
            match_word = 1'b1;
        end else if (dlen == 2) begin
          // Two-letter: exact match of both letters
          if (sub[0] == dchars[0] && sub[1] == dchars[1])
            match_word = 1'b1;
        end else begin
          // len >= 3: first/last equal and inner-letter multiset equal
          if (sub[0] == dchars[0] && sub[dlen-1] == dchars[dlen-1]) begin
            t_inner_sig(sub, dlen, sig_s);
            t_inner_sig(dchars, dlen, sig_d);
            match_word = 1'b1;
            for (k = 0; k < 26; k = k + 1) begin
              if (sig_s[k] != sig_d[k]) begin
                match_word = 1'b0;
              end
            end
          end
        end
      end
    end
  endfunction

  // Build solution string (with spaces) from path_word_idx/len
  task automatic t_build_solution;
    integer d, k;
    reg [7:0] ch;
    reg [7:0] dch [0:MAX_WORD_LEN-1];
    reg [3:0] dlen_local;
    begin
      build_str = 128'd0;
      build_len = 4'd0;
      for (d = 0; d < cur_depth; d = d + 1) begin
        // fetch dict word data
        dlen_local = path_word_len[d];
        for (k = 0; k < MAX_WORD_LEN; k = k + 1) begin
          dch[k] = dict_char[path_word_idx[d]][k];
        end
        // append word
        for (k = 0; k < dlen_local; k = k + 1) begin
          if (build_len < MAX_IN_LEN) begin
            ch = dch[k];
            build_str[8*(MAX_IN_LEN-1-build_len) +: 8] = ch;
            build_len = build_len + 1'b1;
          end
        end
        // append space if not last word and space fits
        if (d != cur_depth-1 && build_len < MAX_IN_LEN) begin
          build_str[8*(MAX_IN_LEN-1-build_len) +: 8] = 8'h20;
          build_len = build_len + 1'b1;
        end
      end
    end
  endtask

  // -------------------- Input decode and FSM --------------------

  // Decode scrambled_str and dict_words when load_inputs is asserted
  always @(*) begin
    // default
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= ST_IDLE;
      deciphered_str  <= 128'd0;
      status          <= 2'b00; // busy/idle
      output_length   <= 4'd0;
      in_len          <= 5'd0;
      cycle_count     <= 8'd0;
      search_active   <= 1'b0;
      solution_count  <= 3'd0;
      cur_pos         <= 5'd0;
      cur_depth       <= 4'd0;
      try_dict_idx    <= 3'd0;
    end else begin
      state <= next_state;

      case (state)
        ST_IDLE: begin
          if (start) begin
            // Load input string bytes
            for (i = 0; i < MAX_IN_LEN; i = i + 1) begin
              in_chars[i] <= scrambled_str[8*(MAX_IN_LEN-1-i) +: 8];
            end
            // Determine length: count non-zero from MSB side
            in_len <= 5'd0;
            for (i = 0; i < MAX_IN_LEN; i = i + 1) begin
              if (scrambled_str[8*(MAX_IN_LEN-1-i) +: 8] != 8'd0)
                in_len <= in_len + 1'b1;
            end
            // Decode dictionary words
            for (i = 0; i < MAX_DICT; i = i + 1) begin
              // bytes
              for (j = 0; j < MAX_WORD_LEN; j = j + 1) begin
                dict_char[i][j] <= dict_words[i][8*(MAX_WORD_LEN-1-j) +: 8];
              end
              // length: non-zero count
              dict_len[i] <= f_dict_len(dict_words[i]);
            end

            // reset search context
            cycle_count    <= 8'd0;
            solution_count <= 3'd0;
            cur_pos        <= 5'd0;
            cur_depth      <= 4'd0;
            try_dict_idx   <= 3'd0;
            search_active  <= 1'b1;
            deciphered_str <= 128'd0;
            output_length  <= 4'd0;
            status         <= 2'b00; // busy
          end
        end

        ST_INIT: begin
          // ensure all decoded; nothing extra
          cycle_count <= cycle_count + 1'b1;
        end

        ST_TRY_SPLIT: begin
          cycle_count <= cycle_count + 1'b1;

          if (!search_active) begin
            // nothing
          end else begin
            // Backtracking search with longest-word-first priority
            // We'll search by trying dictionary entries from longest to shortest at each pos.
            // Implementation: at entry to this state for a given (cur_pos,cur_depth), we
            // iterate try_dict_idx over all words and pick first match with max length.

            have_match_candidate = 1'b0;
            match_word_len       = 4'd0;
            match_dict_idx       = 3'd0;

            // Determine best match at current position
            for (i = 0; i < MAX_DICT; i = i + 1) begin
              if (i < word_count && dict_len[i] != 0) begin
                if (match_word(cur_pos, in_chars, in_len, dict_char[i], dict_len[i])) begin
                  if (!have_match_candidate || dict_len[i] > match_word_len) begin
                    have_match_candidate = 1'b1;
                    match_word_len       = dict_len[i];
                    match_dict_idx       = i[2:0];
                  end
                end
              end
            end

            if (have_match_candidate) begin
              // take this word (longest at this pos)
              path_word_idx[cur_depth] <= match_dict_idx;
              path_word_len[cur_depth] <= match_word_len;
              cur_depth                <= cur_depth + 1'b1;
              cur_pos                  <= cur_pos + match_word_len;

              // If reach end, record solution
              if (cur_pos + match_word_len == in_len) begin
                t_build_solution();
                if (solution_count < MAX_SOL) begin
                  solution_str[solution_count] <= build_str;
                  solution_len[solution_count] <= build_len;
                  solution_count               <= solution_count + 1'b1;
                end

                // Backtrack one level
                if (cur_depth > 0) begin
                  cur_depth <= cur_depth; // already +1 then will be adjusted
                end

                // backtrack: move up one depth and force alternate search by
                // invalidating last choice via advancing cur_pos using length removal
                if (cur_depth > 0) begin
                  cur_depth <= cur_depth - 1'b1;
                  cur_pos   <= cur_pos - match_word_len;
                end
              end
            end else begin
              // no word fits at this position: backtrack
              if (cur_depth == 0) begin
                // no more possibilities
                search_active <= 1'b0;
              end else begin
                // remove last word and stop (we rely on re-try next cycles, but to
                // keep within simple single-longest policy, just backtrack once)
                cur_depth <= cur_depth - 1'b1;
                cur_pos   <= cur_pos - path_word_len[cur_depth-1];
              end
            end
          end
        end

        ST_EVAL: begin
          // evaluate solutions and assign outputs
          if (solution_count == 0) begin
            status         <= 2'b11; // impossible
            deciphered_str <= 128'd0;
            output_length  <= 4'd0;
          end else if (solution_count == 1) begin
            status         <= 2'b01; // done single
            deciphered_str <= solution_str[0];
            output_length  <= solution_len[0];
          end else begin
            status         <= 2'b10; // ambiguous
            deciphered_str <= solution_str[0]; // return one valid
            output_length  <= solution_len[0];
          end
        end

        ST_DONE: begin
          // Hold results until next start or reset
          if (start) begin
            // reinitialize through IDLE-> on next_state
            cycle_count    <= 8'd0;
            solution_count <= 3'd0;
            cur_pos        <= 5'd0;
            cur_depth      <= 4'd0;
            try_dict_idx   <= 3'd0;
            search_active  <= 1'b0;
          end
        end

        default: ;
      endcase

      // Timeout: if exceeded 256 cycles while active, stop search and evaluate best found
      if (state != ST_IDLE && state != ST_DONE && cycle_count >= 8'd255) begin
        search_active <= 1'b0;
      end
    end
  end

  // -------------------- Next-state logic --------------------
  always @(*) begin
    next_state = state;
    case (state)
      ST_IDLE: begin
        if (start)
          next_state = ST_INIT;
      end

      ST_INIT: begin
        // move to search
        next_state = ST_TRY_SPLIT;
      end

      ST_TRY_SPLIT: begin
        if (!search_active) begin
          next_state = ST_EVAL;
        end else if (cycle_count >= 8'd255) begin
          next_state = ST_EVAL;
        end else begin
          next_state = ST_TRY_SPLIT;
        end
      end

      ST_EVAL: begin
        next_state = ST_DONE;
      end

      ST_DONE: begin
        if (start)
          next_state = ST_INIT;
      end

      default: next_state = ST_IDLE;
    endcase
  end

endmodule