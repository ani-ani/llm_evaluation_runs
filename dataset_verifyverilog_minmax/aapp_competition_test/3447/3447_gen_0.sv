module t9_keypad (
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] dict [0:7],   // 8 dictionary words (8 chars each, 8-bit ASCII)
  input [7:0][0] query_word,     // Query word (8 chars max)
  output logic [7:0] key_seq [0:31], // Key sequence (32 elements max)
  output logic [5:0] seq_len,
  output logic done
);

  // Mapping helpers
  function [3:0] map_char_to_digit(input [7:0] ch);
    // T9 mapping (no 0 or 1), letters only (case-insensitive). Others map to 0 (invalid).
    casez (ch)
      "A","a","B","b","C","c": map_char_to_digit = 4'd2;
      "D","d","E","e","F","f": map_char_to_digit = 4'd3;
      "G","g","H","h","I","i": map_char_to_digit = 4'd4;
      "J","j","K","k","L","l": map_char_to_digit = 4'd5;
      "M","m","N","n","O","o": map_char_to_digit = 4'd6;
      "P","p","Q","q","R","r","S","s": map_char_to_digit = 4'd7;
      "T","t","U","u","V","v": map_char_to_digit = 4'd8;
      "W","w","X","x","Y","y","Z","z": map_char_to_digit = 4'd9;
      default: map_char_to_digit = 4'd0;
    endcase
  endfunction

  function [7:0] digit_to_ascii(input [3:0] d);
    digit_to_ascii = 8'h30 | d[3:0];
  endfunction

  function int word_len(input [7:0][0] s);
    int i;
    for (i = 0; i < 8; i++) begin
      if (s[i] == 8'h00) begin
        return i; // stop at first null
      end
    end
    return 8;
  endfunction

  function logic eq_str(input [7:0][0] a, input [7:0][0] b);
    int i;
    for (i = 0; i < 8; i++) begin
      if (a[i] != b[i]) begin
        return 1'b0;
      end
    end
    return 1'b1;
  endfunction

  function int digit_count(input int n);
    // n in [0..7], safe for our use
    if (n < 10) return 1;
    return 2;
  endfunction

  // Push helpers for building sequence
  task push_digit(input [3:0] d, ref int out_idx);
    if (out_idx < 32) begin
      key_seq[out_idx] = digit_to_ascii(d);
      out_idx++;
    end
  endtask

  task push_R(ref int out_idx);
    if (out_idx < 32) begin
      key_seq[out_idx] = 8'h52; // 'R'
      out_idx++;
    end
  endtask

  task push_U_cnt(input int cnt, ref int out_idx);
    // Emit 'U' + decimal count (as ASCII digits). Count limited to [0..7] for our cost model.
    if (out_idx < 32) begin
      key_seq[out_idx] = 8'h55; // 'U'
      out_idx++;
    end
    if (out_idx < 32) begin
      if (cnt >= 10) begin
        key_seq[out_idx] = 8'h31; // '1'
        out_idx++;
        if (out_idx < 32) begin
          key_seq[out_idx] = digit_to_ascii(cnt - 10);
          out_idx++;
        end
      end else begin
        key_seq[out_idx] = digit_to_ascii(cnt);
        out_idx++;
      end
    end
  endtask

  task push_D_cnt(input int cnt, ref int out_idx);
    if (out_idx < 32) begin
      key_seq[out_idx] = 8'h44; // 'D'
      out_idx++;
    end
    if (out_idx < 32) begin
      if (cnt >= 10) begin
        key_seq[out_idx] = 8'h31; // '1'
        out_idx++;
        if (out_idx < 32) begin
          key_seq[out_idx] = digit_to_ascii(cnt - 10);
          out_idx++;
        end
      end else begin
        key_seq[out_idx] = digit_to_ascii(cnt);
        out_idx++;
      end
    end
  endtask

  // States
  typedef enum logic [1:0] {IDLE=2'b00, PROC=2'b01, DONE=2'b10} state_t;
  state_t st, st_next;

  // DP memory
  int dp_cost[0:8];
  int dp_prev[0:8]; // -1 = start
  int dp_words[0:8];
  int dp_chooser[0:8]; // 8 -> undefined; 0..7 chosen dict word idx at this cut

  logic [7:0] digit_seq [0:7];
  int q_len;
  logic valid_query;
  logic [7:0] dict_len [0:7];
  logic dict_match [0:7][0:7]; // dict_match[i][j] = 1 if dict[i] == prefix length j+1 of query

  logic [5:0] delay_cnt, delay_cnt_next;

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st <= IDLE;
      delay_cnt <= 6'd0;
      for (int i = 0; i < 32; i++) key_seq[i] <= 8'h00;
      seq_len <= 6'd0;
      done <= 1'b0;
    end else begin
      st <= st_next;
      delay_cnt <= delay_cnt_next;
      // Outputs are assigned in state blocks; keep default safe on reset/idle.
      if (st == IDLE) begin
        for (int i = 0; i < 32; i++) key_seq[i] <= 8'h00;
        seq_len <= 6'd0;
        done <= 1'b0;
      end
    end
  end

  // Next state and computation
  always_comb begin
    st_next = st;
    delay_cnt_next = delay_cnt;
    case (st)
      IDLE: begin
        if (start) begin
          // Precompute length and validity of query
          q_len = word_len(query_word);
          valid_query = 1'b1;
          for (int i = 0; i < q_len; i++) begin
            if (map_char_to_digit(query_word[i]) == 4'd0) begin
              valid_query = 1'b0;
            end
          end

          // Build digit sequence (up to first null)
          for (int i = 0; i < 8; i++) begin
            if (i < q_len) begin
              digit_seq[i] = digit_to_ascii(map_char_to_digit(query_word[i]));
            end else begin
              digit_seq[i] = 8'h00;
            end
          end

          // Precompute dict lengths and matches
          for (int i = 0; i < 8; i++) begin
            dict_len[i] = word_len(dict[i]);
            for (int j = 0; j < 8; j++) begin
              // match if dict[i][0..j] == query[0..j] and j < dict_len and j < q_len
              dict_match[i][j] = 1'b0;
              if ((j < dict_len[i]) && (j < q_len)) begin
                dict_match[i][j] = eq_str(dict[i][0:j], query_word[0:j]);
              end
            end
          end

          // Initialize DP
          for (int i = 0; i <= 8; i++) begin
            dp_cost[i] = 32'h7fffffff;
            dp_prev[i] = -1;
            dp_words[i] = 0;
            dp_chooser[i] = 8; // undefined
          end

          dp_cost[0] = 0;

          // Dynamic programming over positions (0..q_len), with up to 4 parts and exact dict matches
          for (int pos = 0; pos < q_len; pos++) begin
            if (dp_cost[pos] == 32'h7fffffff) continue;
            // Current number of words used up to pos
            int words_used = dp_words[pos];
            if (words_used >= 4) continue; // limit to 4 parts
            for (int d = 0; d < 8; d++) begin
              int L = dict_len[d];
              if ((L > 0) && (pos + L <= q_len) && dict_match[d][L-1]) begin
                int Ucnt = (d <= 3) ? d : (8 - d); // min distance to key (favor d <= 3)
                int cost = dp_cost[pos] + L + Ucnt;
                int new_words = words_used + 1;
                int next_pos = pos + L;
                // Tie-breakers: fewer words is better; if equal, prefer smaller dictionary index (more common first)
                if (cost < dp_cost[next_pos] ||
                    (cost == dp_cost[next_pos] && new_words < dp_words[next_pos]) ||
                    (cost == dp_cost[next_pos] && new_words == dp_words[next_pos] && d < dp_chooser[next_pos])) begin
                  dp_cost[next_pos] = cost;
                  dp_prev[next_pos] = pos;
                  dp_words[next_pos] = new_words;
                  dp_chooser[next_pos] = d;
                end
              end
            end
          end

          // 10-cycle delay before result
          delay_cnt_next = 6'd0;
          st_next = (valid_query && (dp_cost[q_len] != 32'h7fffffff)) ? PROC : IDLE;
        end else begin
          st_next = IDLE;
        end
      end

      PROC: begin
        delay_cnt_next = delay_cnt + 1;
        if (delay_cnt == 6'd9) begin
          // Build output sequence for the optimal chain
          int out_idx;
          out_idx = 0;
          for (int i = 0; i < 32; i++) key_seq[i] = 8'h00;

          if (valid_query && (dp_cost[q_len] != 32'h7fffffff)) begin
            // Reconstruct path
            int pos;
            int seg_words [0:3];
            int seg_dict  [0:3];
            int seg_len   [0:3];
            int seg_count;
            pos = q_len;
            seg_count = 0;
            while (pos > 0) begin
              int d;
              int prev;
              d = dp_chooser[pos];
              prev = dp_prev[pos];
              seg_words[seg_count] = d;
              seg_len[seg_count] = dict_len[d];
              seg_count++;
              pos = prev;
            end
            // seg_count words from last to first
            for (int s = seg_count - 1; s >= 0; s--) begin
              int d;
              int L;
              int Ucnt;
              d = seg_words[s];
              L = seg_len[s];
              Ucnt = (d <= 3) ? d : (8 - d);

              // Digits for this segment
              for (int k = 0; k < L; k++) begin
                if (out_idx < 32) begin
                  key_seq[out_idx] = digit_seq[k];
                  out_idx++;
                end
              end
              // Between parts: 1 R and U/D + decimal digits
              if (s > 0) begin
                push_R(out_idx);
                if (Ucnt <= 7) begin
                  // Push absolute presses count as U or D + decimal
                  push_U_cnt(Ucnt, out_idx);
                end else begin
                  // Should not happen per cost model; fallback to a single U
                  push_U_cnt(1, out_idx);
                end
              end
            end
          end
          seq_len = out_idx[5:0];
          done = 1'b1;
          st_next = DONE;
        end
      end

      DONE: begin
        // Hold done until next start/reset
        done = 1'b1;
        if (!start) begin
          st_next = IDLE;
        end else begin
          st_next = DONE;
        end
      end
    endcase
  end

endmodule
