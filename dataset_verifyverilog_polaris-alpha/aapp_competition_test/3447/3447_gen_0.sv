module t9_keypad(
  input              clk,
  input              rst_n,
  input              start,
  input      [7:0][7:0] dict [0:7],
  input      [7:0][7:0] query_word,
  output reg [7:0]   key_seq [0:31],
  output reg [5:0]   seq_len,
  output reg         done
);

  // ------------------------------------------------------------
  // Internal signals and parameters
  // ------------------------------------------------------------

  typedef struct packed {
    logic        valid;
    logic [1:0]  dict_idx;      // 0..3 (we only need 3 bits but 2 bits OK for 0..3, adjust if needed)
    logic [2:0]  pos;           // 0..7
    logic [3:0]  len;           // 1..8
    logic [3:0]  cost_ud;       // up/down presses cost
  } part_t;

  typedef struct packed {
    logic        valid;
    logic [3:0]  parts;         // number of parts (1..4)
    logic [3:0]  total_cost;    // cost = total digits + UD + R presses
    // store up to 4 parts
    part_t       p0;
    part_t       p1;
    part_t       p2;
    part_t       p3;
  } chain_t;

  // Maximums per spec
  localparam int MAX_WORDS   = 8;
  localparam int MAX_LEN     = 8;
  localparam int MAX_PARTS   = 4;
  localparam int MAX_KEYSEQ  = 32;

  // FSM states (simple cycle counter based)
  reg [3:0]  cycle_cnt;
  reg        busy;

  // T9-mapped version of dictionary and query
  reg [7:0] dict_t9   [0:MAX_WORDS-1][0:MAX_LEN-1];
  reg [7:0] query_t9  [0:MAX_LEN-1];

  // Precomputed lengths of dictionary words and query_word
  reg [3:0] dict_len  [0:MAX_WORDS-1];
  reg [3:0] query_len;

  // All candidate parts (segments) starting at positions 0..7, up to 4 parts in a chain
  part_t parts_pos [0:MAX_LEN-1][0:MAX_PARTS-1];

  // Best chain result
  chain_t best_chain;

  // ------------------------------------------------------------
  // Character to T9 digit mapping (ASCII in, ASCII digit out)
  // ------------------------------------------------------------
  function automatic [7:0] map_char_to_t9(input [7:0] c);
    begin
      case (c)
        "A","B","C","a","b","c": map_char_to_t9 = "2";
        "D","E","F","d","e","f": map_char_to_t9 = "3";
        "G","H","I","g","h","i": map_char_to_t9 = "4";
        "J","K","L","j","k","l": map_char_to_t9 = "5";
        "M","N","O","m","n","o": map_char_to_t9 = "6";
        "P","Q","R","S","p","q","r","s": map_char_to_t9 = "7";
        "T","U","V","t","u","v": map_char_to_t9 = "8";
        "W","X","Y","Z","w","x","y","z": map_char_to_t9 = "9";
        default: map_char_to_t9 = 8'h30; // '0' for unsupported
      endcase
    end
  endfunction

  // Compute string length up to 8 chars, stopping at 0x00
  function automatic [3:0] str_len8(input [7:0] s [0:7]);
    integer i;
    begin
      str_len8 = 0;
      for (i = 0; i < MAX_LEN; i = i + 1) begin
        if (s[i] != 8'h00)
          str_len8 = str_len8 + 1;
        else
          break;
      end
    end
  endfunction

  // Exact match T9 segment against dictionary T9 entry
  function automatic part_t find_part(
      input [7:0] t9_query [0:MAX_LEN-1],
      input [3:0] start_idx,
      input [3:0] q_len,
      input [7:0] dict_t9_l [0:MAX_WORDS-1][0:MAX_LEN-1],
      input [3:0] dict_len_l [0:MAX_WORDS-1]
    );
    part_t res;
    integer w, j;
    logic match;
    res.valid   = 1'b0;
    res.dict_idx = '0;
    res.pos      = '0;
    res.len      = '0;
    res.cost_ud  = '0;

    // Try each dictionary word by position (0 = most common)
    for (w = 0; w < MAX_WORDS; w = w + 1) begin
      if (!res.valid) begin
        if (dict_len_l[w] != 0 && start_idx + dict_len_l[w] <= q_len) begin
          match = 1'b1;
          for (j = 0; j < MAX_LEN; j = j + 1) begin
            if (j < dict_len_l[w]) begin
              if (t9_query[start_idx + j] != dict_t9_l[w][j]) begin
                match = 1'b0;
              end
            end
          end
          if (match) begin
            res.valid    = 1'b1;
            res.dict_idx = w[1:0];
            res.pos      = w[2:0];
            res.len      = dict_len_l[w];
            // cost_ud = min(pos, (8 - pos - 1)) per spec with 8 words
            if (w < (MAX_WORDS - 1 - w))
              res.cost_ud = w[3:0];
            else
              res.cost_ud = (MAX_WORDS - 1 - w)[3:0];
          end
        end
      end
    end
    return res;
  endfunction

  // Build best chain given precomputed parts_pos
  function automatic chain_t select_best_chain(
      input part_t parts   [0:MAX_LEN-1][0:MAX_PARTS-1],
      input [3:0]  q_len
    );
    chain_t best;
    chain_t cur;
    integer i0, i1, i2, i3;
    integer start0, start1, start2, start3;
    integer used_len;
    integer cost;

    best.valid      = 1'b0;
    best.total_cost = '1; // large
    best.parts      = 0;
    best.p0.valid   = 1'b0;
    best.p1.valid   = 1'b0;
    best.p2.valid   = 1'b0;
    best.p3.valid   = 1'b0;

    // Helper task-like function inline: evaluate a sequence of k parts
    // Here implemented via loops / conditions.

    // 1-part chains
    for (i0 = 0; i0 < MAX_PARTS; i0 = i0 + 1) begin
      cur.valid = 1'b0;
      if (parts[0][i0].valid) begin
        used_len = parts[0][i0].len;
        if (used_len == q_len) begin
          cost = parts[0][i0].len + parts[0][i0].cost_ud; // no R
          cur.valid       = 1'b1;
          cur.parts       = 1;
          cur.p0          = parts[0][i0];
          cur.p1.valid    = 1'b0;
          cur.p2.valid    = 1'b0;
          cur.p3.valid    = 1'b0;
          cur.total_cost  = cost[3:0];
        end
      end
      if (cur.valid && (!best.valid || cur.total_cost < best.total_cost))
        best = cur;
    end

    // 2-part chains
    for (i0 = 0; i0 < MAX_PARTS; i0 = i0 + 1) begin
      if (!parts[0][i0].valid) continue;
      start0 = 0;
      start1 = parts[0][i0].len;
      if (start1 >= q_len) continue;
      for (i1 = 0; i1 < MAX_PARTS; i1 = i1 + 1) begin
        if (!parts[start1][i1].valid) continue;
        used_len = parts[0][i0].len + parts[start1][i1].len;
        if (used_len == q_len) begin
          cost = parts[0][i0].len + parts[0][i0].cost_ud +
                 parts[start1][i1].len + parts[start1][i1].cost_ud +
                 1; // one R between parts
          cur.valid      = 1'b1;
          cur.parts      = 2;
          cur.p0         = parts[0][i0];
          cur.p1         = parts[start1][i1];
          cur.p2.valid   = 1'b0;
          cur.p3.valid   = 1'b0;
          cur.total_cost = cost[3:0];
          if (!best.valid || cur.total_cost < best.total_cost)
            best = cur;
        end
      end
    end

    // 3-part chains
    for (i0 = 0; i0 < MAX_PARTS; i0 = i0 + 1) begin
      if (!parts[0][i0].valid) continue;
      start0 = 0;
      start1 = parts[0][i0].len;
      if (start1 >= q_len) continue;
      for (i1 = 0; i1 < MAX_PARTS; i1 = i1 + 1) begin
        if (!parts[start1][i1].valid) continue;
        start2 = start1 + parts[start1][i1].len;
        if (start2 >= q_len) continue;
        for (i2 = 0; i2 < MAX_PARTS; i2 = i2 + 1) begin
          if (!parts[start2][i2].valid) continue;
          used_len = parts[0][i0].len + parts[start1][i1].len + parts[start2][i2].len;
          if (used_len == q_len) begin
            cost = parts[0][i0].len + parts[0][i0].cost_ud +
                   parts[start1][i1].len + parts[start1][i1].cost_ud +
                   parts[start2][i2].len + parts[start2][i2].cost_ud +
                   2; // two R's
            cur.valid      = 1'b1;
            cur.parts      = 3;
            cur.p0         = parts[0][i0];
            cur.p1         = parts[start1][i1];
            cur.p2         = parts[start2][i2];
            cur.p3.valid   = 1'b0;
            cur.total_cost = cost[3:0];
            if (!best.valid || cur.total_cost < best.total_cost)
              best = cur;
          end
        end
      end
    end

    // 4-part chains
    for (i0 = 0; i0 < MAX_PARTS; i0 = i0 + 1) begin
      if (!parts[0][i0].valid) continue;
      start0 = 0;
      start1 = parts[0][i0].len;
      if (start1 >= q_len) continue;
      for (i1 = 0; i1 < MAX_PARTS; i1 = i1 + 1) begin
        if (!parts[start1][i1].valid) continue;
        start2 = start1 + parts[start1][i1].len;
        if (start2 >= q_len) continue;
        for (i2 = 0; i2 < MAX_PARTS; i2 = i2 + 1) begin
          if (!parts[start2][i2].valid) continue;
          start3 = start2 + parts[start2][i2].len;
          if (start3 >= q_len) continue;
          for (i3 = 0; i3 < MAX_PARTS; i3 = i3 + 1) begin
            if (!parts[start3][i3].valid) continue;
            used_len = parts[0][i0].len + parts[start1][i1].len +
                       parts[start2][i2].len + parts[start3][i3].len;
            if (used_len == q_len) begin
              cost = parts[0][i0].len + parts[0][i0].cost_ud +
                     parts[start1][i1].len + parts[start1][i1].cost_ud +
                     parts[start2][i2].len + parts[start2][i2].cost_ud +
                     parts[start3][i3].len + parts[start3][i3].cost_ud +
                     3; // three R's
              cur.valid      = 1'b1;
              cur.parts      = 4;
              cur.p0         = parts[0][i0];
              cur.p1         = parts[start1][i1];
              cur.p2         = parts[start2][i2];
              cur.p3         = parts[start3][i3];
              cur.total_cost = cost[3:0];
              if (!best.valid || cur.total_cost < best.total_cost)
                best = cur;
            end
          end
        end
      end
    end

    return best;
  endfunction

  // Encode a small decimal (0-7) as ASCII. We only need for UD counts 0..3.
  function automatic [7:0] dec_to_ascii(input [3:0] v);
    begin
      dec_to_ascii = 8'h30 + v[3:0];
    end
  endfunction

  // ------------------------------------------------------------
  // Sequential control: 10-cycle latency after start
  // ------------------------------------------------------------
  integer i, j;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done      <= 1'b0;
      seq_len   <= 6'd0;
      busy      <= 1'b0;
      cycle_cnt <= 4'd0;
      for (i = 0; i < MAX_KEYSEQ; i = i + 1) begin
        key_seq[i] <= 8'h00;
      end
    end else begin
      if (start && !busy) begin
        // Start operation
        busy      <= 1'b1;
        cycle_cnt <= 4'd0;
        done      <= 1'b0;
      end

      if (busy) begin
        cycle_cnt <= cycle_cnt + 4'd1;

        // Pipeline actions by cycle count (not deeply optimized, but fixed 10 cycles total)

        // Cycle 1: compute lengths
        if (cycle_cnt == 4'd1) begin
          query_len <= str_len8(query_word);
          for (i = 0; i < MAX_WORDS; i = i + 1) begin
            dict_len[i] <= str_len8(dict[i]);
          end
        end

        // Cycle 2: build T9 for dictionary
        if (cycle_cnt == 4'd2) begin
          for (i = 0; i < MAX_WORDS; i = i + 1) begin
            for (j = 0; j < MAX_LEN; j = j + 1) begin
              if (dict[i][j] != 8'h00)
                dict_t9[i][j] <= map_char_to_t9(dict[i][j]);
              else
                dict_t9[i][j] <= 8'h00;
            end
          end
        end

        // Cycle 3: build T9 for query
        if (cycle_cnt == 4'd3) begin
          for (j = 0; j < MAX_LEN; j = j + 1) begin
            if (query_word[j] != 8'h00)
              query_t9[j] <= map_char_to_t9(query_word[j]);
            else
              query_t9[j] <= 8'h00;
          end
        end

        // Cycle 4-6: compute candidate parts for each start index
        if (cycle_cnt == 4'd4 || cycle_cnt == 4'd5 || cycle_cnt == 4'd6) begin
          // Single-pass combinational-like generation gated in time
          for (i = 0; i < MAX_LEN; i = i + 1) begin
            for (j = 0; j < MAX_PARTS; j = j + 1) begin
              parts_pos[i][j].valid   <= 1'b0;
              parts_pos[i][j].dict_idx<= '0;
              parts_pos[i][j].pos     <= '0;
              parts_pos[i][j].len     <= '0;
              parts_pos[i][j].cost_ud <= '0;
            end
          end
          for (i = 0; i < MAX_LEN; i = i + 1) begin
            part_t tmp;
            if (i < query_len) begin
              tmp = find_part(query_t9, i[3:0], query_len, dict_t9, dict_len);
              if (tmp.valid) begin
                parts_pos[i][0] <= tmp;
              end
            end
          end
        end

        // Cycle 7: select best chain
        if (cycle_cnt == 4'd7) begin
          best_chain <= select_best_chain(parts_pos, query_len);
        end

        // Cycle 8-9: format output sequence from best_chain
        if (cycle_cnt == 4'd8) begin
          integer idx;
          idx = 0;
          // Clear previous
          for (i = 0; i < MAX_KEYSEQ; i = i + 1) begin
            key_seq[i] <= 8'h00;
          end

          if (best_chain.valid) begin
            part_t pp;
            // helper task inlined using repeat for up to 4 parts
            // Part 0
            if (best_chain.parts > 0 && best_chain.p0.valid) begin
              pp = best_chain.p0;
              // digits from query_t9
              for (j = 0; j < pp.len && idx < MAX_KEYSEQ; j = j + 1) begin
                key_seq[idx] <= query_t9[(idx==0)?0:(0) + j]; // corrected below
              end
            end
          end
        end

        // Because we cannot have local loops with dynamic offsets easily in above block,
        // redo formatting cleanly at cycle 9 using best_chain and query_t9.
        if (cycle_cnt == 4'd9) begin
          integer k;
          integer pos_q;
          integer out_idx;
          part_t pp_local;

          // reset
          for (k = 0; k < MAX_KEYSEQ; k = k + 1) begin
            key_seq[k] <= 8'h00;
          end

          out_idx = 0;
          pos_q   = 0;

          if (best_chain.valid) begin
            // macro-like: process each part in order p0..p3
            // We'll unroll manually due to SV function/task restrictions here.

            // process part p0
            if (best_chain.parts > 0 && best_chain.p0.valid) begin
              pp_local = best_chain.p0;
              // digits
              for (k = 0; k < pp_local.len && out_idx < MAX_KEYSEQ; k = k + 1) begin
                key_seq[out_idx] <= query_t9[pos_q + k];
                out_idx = out_idx + 1;
              end
              pos_q = pos_q + pp_local.len;
              // U/D encoding if cost_ud > 0: 'U' + ascii(count)
              if (pp_local.cost_ud != 0 && out_idx + 1 < MAX_KEYSEQ) begin
                key_seq[out_idx]     <= 8'h55; // 'U'
                key_seq[out_idx + 1] <= dec_to_ascii(pp_local.cost_ud);
                out_idx = out_idx + 2;
              end
              // 'R' between parts
              if (best_chain.parts > 1 && out_idx < MAX_KEYSEQ) begin
                key_seq[out_idx] <= 8'h52; // 'R'
                out_idx = out_idx + 1;
              end
            end

            // process part p1
            if (best_chain.parts > 1 && best_chain.p1.valid && out_idx < MAX_KEYSEQ) begin
              pp_local = best_chain.p1;
              for (k = 0; k < pp_local.len && out_idx < MAX_KEYSEQ; k = k + 1) begin
                key_seq[out_idx] <= query_t9[pos_q + k];
                out_idx = out_idx + 1;
              end
              pos_q = pos_q + pp_local.len;
              if (pp_local.cost_ud != 0 && out_idx + 1 < MAX_KEYSEQ) begin
                key_seq[out_idx]     <= 8'h55; // 'U'
                key_seq[out_idx + 1] <= dec_to_ascii(pp_local.cost_ud);
                out_idx = out_idx + 2;
              end
              if (best_chain.parts > 2 && out_idx < MAX_KEYSEQ) begin
                key_seq[out_idx] <= 8'h52; // 'R'
                out_idx = out_idx + 1;
              end
            end

            // process part p2
            if (best_chain.parts > 2 && best_chain.p2.valid && out_idx < MAX_KEYSEQ) begin
              pp_local = best_chain.p2;
              for (k = 0; k < pp_local.len && out_idx < MAX_KEYSEQ; k = k + 1) begin
                key_seq[out_idx] <= query_t9[pos_q + k];
                out_idx = out_idx + 1;
              end
              pos_q = pos_q + pp_local.len;
              if (pp_local.cost_ud != 0 && out_idx + 1 < MAX_KEYSEQ) begin
                key_seq[out_idx]     <= 8'h55; // 'U'
                key_seq[out_idx + 1] <= dec_to_ascii(pp_local.cost_ud);
                out_idx = out_idx + 2;
              end
              if (best_chain.parts > 3 && out_idx < MAX_KEYSEQ) begin
                key_seq[out_idx] <= 8'h52; // 'R'
                out_idx = out_idx + 1;
              end
            end

            // process part p3
            if (best_chain.parts > 3 && best_chain.p3.valid && out_idx < MAX_KEYSEQ) begin
              pp_local = best_chain.p3;
              for (k = 0; k < pp_local.len && out_idx < MAX_KEYSEQ; k = k + 1) begin
                key_seq[out_idx] <= query_t9[pos_q + k];
                out_idx = out_idx + 1;
              end
              pos_q = pos_q + pp_local.len;
              if (pp_local.cost_ud != 0 && out_idx + 1 < MAX_KEYSEQ) begin
                key_seq[out_idx]     <= 8'h55; // 'U'
                key_seq[out_idx + 1] <= dec_to_ascii(pp_local.cost_ud);
                out_idx = out_idx + 2;
              end
            end

            seq_len <= out_idx[5:0];
          end else begin
            // No valid chain: output empty
            seq_len <= 6'd0;
          end
        end

        // Cycle 10: assert done and stop
        if (cycle_cnt == 4'd10) begin
          done      <= 1'b1;
          busy      <= 1'b0;
          cycle_cnt <= 4'd0;
        end
      end else begin
        // idle
        done <= 1'b0;
      end
    end
  end

endmodule