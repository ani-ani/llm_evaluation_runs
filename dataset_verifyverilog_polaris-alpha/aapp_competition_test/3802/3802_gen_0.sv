module virus_free_lcs(
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] s1,
  input [7:0][7:0] s2,
  input [7:0][7:0] virus,
  output reg [63:0] result,
  output reg done,
  output reg valid
);

  // ---------------------------------------------------------------------------
  // Parameters and State Encoding
  // ---------------------------------------------------------------------------
  localparam IDLE          = 3'd0;
  localparam KMP_PREPROCESS= 3'd1;
  localparam DP_FILL       = 3'd2;
  localparam BACKTRACE     = 3'd3;
  localparam DONE          = 3'd4;

  reg [2:0] state, next_state;

  // ---------------------------------------------------------------------------
  // Virus length detection (scan up to 8 chars, zero-terminated)
  // ---------------------------------------------------------------------------
  // virus_len in [0..8]
  reg [3:0] virus_len;
  integer vl_i;

  always @(*) begin
    virus_len = 4'd0;
    for (vl_i = 0; vl_i < 8; vl_i = vl_i + 1) begin
      if (virus[vl_i] != 8'd0)
        virus_len = vl_i + 1;
    end
  end

  // ---------------------------------------------------------------------------
  // KMP failure function and transition table
  // ---------------------------------------------------------------------------
  // fail[i]: longest proper prefix which is also suffix for virus[0..i]
  // max virus_len = 8 -> index 0..7, store 4 bits each
  reg [3:0] fail [0:7];

  // next_state_kmp[cur][ch] where
  //  cur in [0..7] (we only allow < virus_len; reaching virus_len is forbidden)
  //  ch is 8-bit char index [0..255]
  // Stored as: next_state_kmp[cur][ch]
  reg [3:0] next_state_kmp [0:7][0:255];

  // KMP preprocess control
  reg [3:0] kmp_i;
  reg [3:0] kmp_j;
  reg [7:0] kmp_ch;
  reg       kmp_fail_done;
  reg       kmp_next_done;

  // ---------------------------------------------------------------------------
  // DP storage
  // ---------------------------------------------------------------------------
  // We implement length DP and direction DP and virus-state DP.
  // Dimensions: i in [0..8], j in [0..8], k in [0..7]
  // Indexing as described by bits:
  // idx = (i*9 + j)*8 + k  ->  i:4 bits, j:4 bits, k:3 bits, idx up to 647
  // But we only use i,j in [0..8], k in [0..7].

  // Length of LCS for each state
  reg [3:0] dp_len [0:8][0:8][0:7];
  // Direction encoding:
  // 2'b00 = from (i-1, j, k)     (UP)
  // 2'b01 = from (i, j-1, k)     (LEFT)
  // 2'b10 = from (i-1, j-1, k_prev) with char match and k transition (DIAG)
  // 2'b11 = unused / none
  reg [1:0] dp_dir [0:8][0:8][0:7];
  // Store previous virus state for DIAG transitions
  reg [2:0] dp_prevk [0:8][0:8][0:7];

  // DP iteration indices
  reg [3:0] dp_i;
  reg [3:0] dp_j;
  reg [2:0] dp_k;

  // Max search after fill
  reg [3:0] max_len;
  reg [3:0] max_i;
  reg [3:0] max_j;
  reg [2:0] max_k;

  // ---------------------------------------------------------------------------
  // Backtrace
  // ---------------------------------------------------------------------------
  reg [3:0] bt_i;
  reg [3:0] bt_j;
  reg [2:0] bt_k;
  reg [3:0] bt_pos;   // counts how many chars placed (0..8)
  reg [63:0] bt_result_shift;

  // ---------------------------------------------------------------------------
  // Utility: KMP next-state function (combinational using table)
  // Note: if virus_len == 0, we treat as no virus constraint; no forbidden.
  // For virus_len > 0, using precomputed next_state_kmp; if result == virus_len
  // then it is forbidden; callers must check and avoid.
  // ---------------------------------------------------------------------------
  function [3:0] kmp_next;
    input [3:0] cur;
    input [7:0] ch;
    begin
      if (virus_len == 0)
        kmp_next = 4'd0;
      else if (cur < 8)
        kmp_next = next_state_kmp[cur][ch];
      else
        kmp_next = 4'd0;
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Sequential State Register
  // ---------------------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  // ---------------------------------------------------------------------------
  // Next State Logic
  // ---------------------------------------------------------------------------
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = KMP_PREPROCESS;
      end
      KMP_PREPROCESS: begin
        if (kmp_fail_done && kmp_next_done)
          next_state = DP_FILL;
      end
      DP_FILL: begin
        // Once dp_i, dp_j, dp_k complete full range and max search done
        if (dp_i == 4'd8 && dp_j == 4'd8 && dp_k == 3'd7)
          next_state = BACKTRACE;
      end
      BACKTRACE: begin
        // Backtrace ends when bt_pos == max_len or indices exhausted
        if (bt_pos == max_len || max_len == 0)
          next_state = DONE;
      end
      DONE: begin
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // ---------------------------------------------------------------------------
  // KMP Preprocessing: build fail[] and next_state_kmp
  // Implemented sequentially for hardware friendliness.
  // ---------------------------------------------------------------------------
  integer x;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      kmp_i <= 0;
      kmp_j <= 0;
      kmp_ch <= 0;
      kmp_fail_done <= 1'b0;
      kmp_next_done <= 1'b0;
      for (x = 0; x < 8; x = x + 1) begin
        fail[x] <= 4'd0;
      end
    end else begin
      if (state == IDLE && start) begin
        // reset KMP preprocess
        kmp_i <= 4'd1;
        kmp_j <= 4'd0;
        kmp_ch <= 8'd0;
        kmp_fail_done <= (virus_len <= 1) ? 1'b1 : 1'b0;
        kmp_next_done <= 1'b0;
        for (x = 0; x < 8; x = x + 1) begin
          fail[x] <= 4'd0;
        end
      end else if (state == KMP_PREPROCESS) begin
        // Step 1: compute fail[] if not done and virus_len>1
        if (!kmp_fail_done) begin
          if (virus_len <= 1) begin
            kmp_fail_done <= 1'b1;
          end else begin
            if (kmp_i < virus_len) begin
              if (kmp_j > 0 && virus[kmp_i] != virus[kmp_j]) begin
                kmp_j <= fail[kmp_j-1];
              end else begin
                if (virus[kmp_i] == virus[kmp_j]) begin
                  kmp_j <= kmp_j + 1;
                  fail[kmp_i] <= kmp_j + 1 - 1; // j (since j incremented next)
                end
                kmp_i <= kmp_i + 1;
              end
            end else begin
              kmp_fail_done <= 1'b1;
              kmp_ch <= 8'd0;
              kmp_i <= 4'd0; // reuse for transition build: cur state
            end
          end
        end else if (!kmp_next_done) begin
          // Step 2: build next_state_kmp table
          // For virus_len==0: no restriction, but we still fill with zeros.
          if (virus_len == 0) begin
            if (kmp_i < 8) begin
              next_state_kmp[kmp_i][kmp_ch] <= 4'd0;
              if (kmp_ch == 8'hFF) begin
                kmp_ch <= 8'd0;
                kmp_i <= kmp_i + 1;
              end else begin
                kmp_ch <= kmp_ch + 1;
              end
            end else begin
              kmp_next_done <= 1'b1;
            end
          end else begin
            // Standard KMP transition: only for cur < virus_len
            if (kmp_i < virus_len && kmp_i < 8) begin
              // compute transition for state kmp_i and char kmp_ch
              reg [3:0] st;
              reg [3:0] jtmp;
              st = kmp_i;
              jtmp = st;
              // follow fail links while mismatch and jtmp>0
              if (kmp_ch == virus[st]) begin
                st = st + 1;
              end else begin
                while (jtmp > 0 && kmp_ch != virus[jtmp]) begin
                  jtmp = fail[jtmp-1];
                end
                if (kmp_ch == virus[jtmp])
                  st = jtmp + 1;
                else
                  st = 0;
              end
              // clamp to < virus_len to avoid accepting full virus
              if (st >= virus_len)
                st = virus_len[3:0];
              next_state_kmp[kmp_i][kmp_ch] <= st;
              if (kmp_ch == 8'hFF) begin
                kmp_ch <= 8'd0;
                kmp_i <= kmp_i + 1;
              end else begin
                kmp_ch <= kmp_ch + 1;
              end
            end else if (kmp_i < 8) begin
              // For states >=virus_len and <8, keep 0
              next_state_kmp[kmp_i][kmp_ch] <= 4'd0;
              if (kmp_ch == 8'hFF) begin
                kmp_ch <= 8'd0;
                kmp_i <= kmp_i + 1;
              end else begin
                kmp_ch <= kmp_ch + 1;
              end
            end else begin
              kmp_next_done <= 1'b1;
            end
          end
        end
      end
    end
  end

  // ---------------------------------------------------------------------------
  // DP Fill
  // Sequential scan over i,j,k
  // dp_len, dp_dir, dp_prevk updated per state
  // ---------------------------------------------------------------------------
  integer ii, jj, kk;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset DP related registers
      dp_i <= 4'd0;
      dp_j <= 4'd0;
      dp_k <= 3'd0;
      max_len <= 4'd0;
      max_i <= 4'd0;
      max_j <= 4'd0;
      max_k <= 3'd0;
      // Clear DP arrays
      for (ii = 0; ii <= 8; ii = ii + 1)
        for (jj = 0; jj <= 8; jj = jj + 1)
          for (kk = 0; kk < 8; kk = kk + 1) begin
            dp_len[ii][jj][kk] <= 4'd0;
            dp_dir[ii][jj][kk] <= 2'b11;
            dp_prevk[ii][jj][kk] <= 3'd0;
          end
    end else begin
      if (state == KMP_PREPROCESS && next_state == DP_FILL) begin
        // Initialize DP just before entering DP_FILL
        dp_i <= 4'd0;
        dp_j <= 4'd0;
        dp_k <= 3'd0;
        max_len <= 4'd0;
        max_i <= 4'd0;
        max_j <= 4'd0;
        max_k <= 3'd0;
        // boundaries already zeroed by reset or assume stable
      end else if (state == DP_FILL) begin
        // Perform one DP cell update per cycle at (dp_i, dp_j, dp_k)
        reg [3:0] best_len;
        reg [1:0] best_dir;
        reg [2:0] best_prevk;
        reg [3:0] cand_len;
        reg [2:0] prevk;

        if (dp_i == 0 || dp_j == 0) begin
          // boundary, length 0
          dp_len[dp_i][dp_j][dp_k] <= 4'd0;
          dp_dir[dp_i][dp_j][dp_k] <= 2'b11;
          dp_prevk[dp_i][dp_j][dp_k] <= 3'd0;
        end else begin
          best_len = 4'd0;
          best_dir = 2'b11;
          best_prevk = 3'd0;

          // Option 1: from top (i-1, j, same k)
          cand_len = dp_len[dp_i-1][dp_j][dp_k];
          if (cand_len > best_len) begin
            best_len = cand_len;
            best_dir = 2'b00;
            best_prevk = dp_k;
          end

          // Option 2: from left (i, j-1, same k)
          cand_len = dp_len[dp_i][dp_j-1][dp_k];
          if (cand_len > best_len) begin
            best_len = cand_len;
            best_dir = 2'b01;
            best_prevk = dp_k;
          end

          // Option 3: match characters if equal and not forming virus
          if (s1[dp_i-1] == s2[dp_j-1]) begin
            // try all previous k' that transition into current k
            for (prevk = 0; prevk < 8; prevk = prevk + 1) begin
              reg [3:0] nxt;
              nxt = kmp_next(prevk, s1[dp_i-1]);
              if (nxt == dp_k && nxt < virus_len) begin
                cand_len = dp_len[dp_i-1][dp_j-1][prevk] + 1;
                if (cand_len > best_len) begin
                  best_len = cand_len;
                  best_dir = 2'b10;
                  best_prevk = prevk;
                end
              end
            end
            // If virus_len==0, no restriction: treat dp_k==0 only
            if (virus_len == 0 && dp_k == 0) begin
              cand_len = dp_len[dp_i-1][dp_j-1][0] + 1;
              if (cand_len > best_len) begin
                best_len = cand_len;
                best_dir = 2'b10;
                best_prevk = 3'd0;
              end
            end
          end

          dp_len[dp_i][dp_j][dp_k] <= best_len;
          dp_dir[dp_i][dp_j][dp_k] <= best_dir;
          dp_prevk[dp_i][dp_j][dp_k] <= best_prevk;

          // Track global max at (8,8, any k != virus_len)
          if (dp_i == 4'd8 && dp_j == 4'd8) begin
            if (best_len > max_len && (virus_len == 0 || dp_k != virus_len[2:0])) begin
              max_len <= best_len;
              max_i <= dp_i;
              max_j <= dp_j;
              max_k <= dp_k;
            end
          end
        end

        // Increment indices: k -> j -> i
        if (dp_k < 3'd7) begin
          dp_k <= dp_k + 1'b1;
        end else begin
          dp_k <= 3'd0;
          if (dp_j < 4'd8) begin
            dp_j <= dp_j + 1'b1;
          end else begin
            dp_j <= 4'd0;
            if (dp_i < 4'd8) begin
              dp_i <= dp_i + 1'b1;
            end else begin
              dp_i <= 4'd8; // stay
            end
          end
        end
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Backtrace logic
  // ---------------------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      bt_i <= 4'd0;
      bt_j <= 4'd0;
      bt_k <= 3'd0;
      bt_pos <= 4'd0;
      bt_result_shift <= 64'd0;
    end else begin
      if (state == DP_FILL && next_state == BACKTRACE) begin
        // Initialize backtrace starting from best endpoint
        bt_i <= max_i;
        bt_j <= max_j;
        bt_k <= max_k;
        bt_pos <= 4'd0;
        bt_result_shift <= 64'd0;
      end else if (state == BACKTRACE) begin
        if (max_len == 0) begin
          // No valid LCS
          bt_result_shift <= 64'd0;
        end else if (bt_pos < max_len && bt_i > 0 && bt_j > 0) begin
          reg [1:0] dir;
          reg [2:0] pk;
          dir = dp_dir[bt_i][bt_j][bt_k];
          pk  = dp_prevk[bt_i][bt_j][bt_k];

          if (dir == 2'b10) begin
            // Diagonal: matched char
            // Insert char at MSB side so final order is correct after done
            bt_result_shift <= {bt_result_shift[55:0], s1[bt_i-1]};
            bt_pos <= bt_pos + 1'b1;
            bt_i <= bt_i - 1'b1;
            bt_j <= bt_j - 1'b1;
            bt_k <= pk;
          end else if (dir == 2'b00) begin
            // Up
            bt_i <= bt_i - 1'b1;
          end else if (dir == 2'b01) begin
            // Left
            bt_j <= bt_j - 1'b1;
          end else begin
            // None or invalid, stop
            bt_pos <= max_len;
          end
        end else begin
          // Finished or indices exhausted
          bt_pos <= max_len;
        end
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Output and DONE state handling
  // ---------------------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 64'd0;
      done   <= 1'b0;
      valid  <= 1'b0;
    end else begin
      done <= 1'b0;
      if (state == BACKTRACE && next_state == DONE) begin
        // Align result: bt_result_shift currently has chars in forward order
        result <= bt_result_shift;
        valid  <= (max_len != 0);
        if (max_len == 0)
          result <= 64'd0;
        done <= 1'b1;
      end else if (state == IDLE && !start) begin
        // Clear outputs between runs
        result <= 64'd0;
        valid  <= 1'b0;
        done   <= 1'b0;
      end
    end
  end

endmodule