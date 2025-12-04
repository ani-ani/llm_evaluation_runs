module virus_free_lcs(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // start computation
  input [7:0][7:0] s1, // first string (8 ASCII chars)
  input [7:0][7:0] s2, // second string (8 ASCII chars)
  input [7:0][7:0] virus, // virus substring (max 8 chars)
  output reg [63:0] result, // output LCS (8 chars packed as 64 bits)
  output reg done, // high when computation complete
  output reg valid // 1=valid LCS, 0=no solution
);

  // FSM states
  localparam IDLE          = 3'b000;
  localparam KMP_PREPROCESS= 3'b001;
  localparam DP_FILL       = 3'b010;
  localparam BACKTRACE     = 3'b011;
  localparam DONE          = 3'b100;

  // Constants
  localparam W = 8; // string width (characters)
  localparam STATES = 8; // KMP states: 0..7
  localparam MAX_CYCLES = 600; // upper bound on completion

  // Internal signals
  reg [2:0] state, next_state;
  reg [9:0] cycle_cnt; // up to 600
  reg [2:0] i_idx, j_idx, k_idx; // current DP indices
  reg [2:0] i_next, j_next, k_next;
  reg start_r;

  // KMP prefix function and next-state table
  reg [2:0] pi [0:7];
  reg [2:0] next_state_k [0:7][0:255];
  reg next_valid [0:7][0:255];
  reg [2:0] virus_len; // length of virus (non-zero char region)

  // DP table: dp[i][j][k] = best length achievable from pos i,j with KMP state k
  reg [3:0] dp [0:7][0:7][0:7];
  // Decision storage (during backtrace we use dp to guide)
  // No additional storage is needed beyond dp.

  // Temporary signals used in fill stage
  wire [7:0] c1 = s1[i_idx];
  wire [7:0] c2 = s2[j_idx];
  wire chars_equal = (c1 == c2);

  // Derived KMP next for current (k, c1)
  wire [2:0] k_next_from_c1 = next_state_k[k_idx][c1];
  wire valid_next_c1 = next_valid[k_idx][c1];

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_cnt <= 10'b0;
      done <= 1'b0;
      valid <= 1'b0;
      result <= 64'b0;
      start_r <= 1'b0;
      // Initialize dp to 0
      for (int ii=0; ii<8; ii++)
        for (int jj=0; jj<8; jj++)
          for (int kk=0; kk<8; kk++)
            dp[ii][jj][kk] <= 4'b0;
    end else begin
      start_r <= start;
      cycle_cnt <= cycle_cnt + 1;
      state <= next_state;
      case (next_state)
        KMP_PREPROCESS: begin
          // pi[0] is always 0 (by definition)
          // At cycle 0 we compute pi[1] if exists, etc.
          // We need 8 cycles (0..7)
          if (cycle_cnt == 10'd0) begin
            pi[0] <= 3'b0;
          end else begin
            // compute pi[t] for t = cycle_cnt-1
            if (cycle_cnt > 0 && cycle_cnt <= 8) begin
              automatic int t = cycle_cnt - 1; // 0..7
              if (t == 0) begin
                pi[t] <= 3'b0;
              end else begin
                automatic int q = pi[t-1];
                // while q>0 and virus[t] != virus[q] -> q = pi[q-1]
                while (q > 0 && virus[t] != virus[q]) q = pi[q-1];
                if (virus[t] == virus[q]) q = q + 1;
                pi[t] <= q[2:0];
              end
            end
          end
        end
        DP_FILL: begin
          // One DP cell per cycle: (i_idx, j_idx, k_idx)
          // Compute next dp value from previous choices
          // We will compute and store dp for (i,j,k) based on (i+1,j,k) and (i,j+1,k)
          // and if s1[i]==s2[j], from (i+1,j+1, next_k) + 1.

          // Determine candidates for dp_next
          automatic reg [3:0] best = 4'b0;
          automatic reg [3:0] skip_i = dp[i_next][j_idx][k_idx]; // from (i+1, j, k)
          automatic reg [3:0] skip_j = dp[i_idx][j_next][k_idx]; // from (i, j+1, k)
          best = (skip_i > skip_j) ? skip_i : skip_j;

          if (chars_equal && valid_next_c1) begin
            automatic reg [3:0] take = dp[i_next][j_next][k_next_from_c1] + 1;
            if (take > best) best = take;
          end
          dp[i_idx][j_idx][k_idx] <= best;
        end
        BACKTRACE: begin
          // We only need result/valid here; done is set going to DONE
          // But we keep them in sync with this state
          done <= 1'b0;
          valid <= valid & 1'b1; // maintain during backtrace if previously set
        end
        DONE: begin
          done <= 1'b1;
        end
        default: ;
      endcase
    end
  end

  // Next-state logic and combinatorial fill
  always @(*) begin
    // Defaults
    next_state = state;
    i_next = i_idx;
    j_next = j_idx;
    k_next = k_idx;

    case (state)
      IDLE: begin
        if (start && !start_r) begin
          next_state = KMP_PREPROCESS;
          // reset counters
          i_next = 3'b0;
          j_next = 3'b0;
          k_next = 3'b0;
        end
      end
      KMP_PREPROCESS: begin
        // After pi is ready (8 cycles), go to DP_FILL
        if (cycle_cnt >= 8) begin
          next_state = DP_FILL;
          i_next = 3'b0;
          j_next = 3'b0;
          k_next = 3'b0;
        end
      end
      DP_FILL: begin
        // Fill 8x8x8 = 512 cells in order
        // We assume each clock computes one cell and advances indices
        if ({i_idx, j_idx, k_idx} == 9'b111_111_111) begin
          // All cells computed, move to backtrace
          next_state = BACKTRACE;
          i_next = 3'b0;
          j_next = 3'b0;
          k_next = 3'b0;
        end else begin
          // advance indices in nested loops: k fastest, then j, then i
          // Build next indices
          // Current: i_idx (3), j_idx(3), k_idx(3) -> combined 9 bits
          automatic int ii = i_idx;
          automatic int jj = j_idx;
          automatic int kk = k_idx;
          kk = kk + 1;
          if (kk == 8) begin
            kk = 0;
            jj = jj + 1;
            if (jj == 8) begin
              jj = 0;
              ii = ii + 1;
            end
          end
          i_next = ii[2:0];
          j_next = jj[2:0];
          k_next = kk[2:0];
          next_state = DP_FILL;
        end
      end
      BACKTRACE: begin
        // After at most 8 steps, go to DONE
        if (cycle_cnt >= 8) begin
          next_state = DONE;
        end
      end
      DONE: begin
        // Wait for start to deassert or cycle timeout; or go back to IDLE
        if (!start) begin
          next_state = IDLE;
        end
      end
      default: next_state = IDLE;
    endcase
  end

  // Compute virus length (stop at first 0x00 char)
  always @(*) begin
    if (rst_n == 1'b0) begin
      virus_len = 3'b0;
    end else begin
      automatic int L = 0;
      for (int t=0; t<8; t++) begin
        if (virus[t] != 8'h00) L = t + 1;
      end
      virus_len = L[2:0];
    end
  end

  // Build KMP next-state transition table (next_state_k and next_valid)
  // This is combinational; it only depends on virus and pi which are ready after KMP_PREPROCESS.
  genvar gi, gj;
  generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : gk
      for (gj = 0; gj < 256; gj = gj + 1) begin : gc
        // Compute next_k for state gi and character gj[7:0]
        // Reject invalid states (gi >= virus_len is generally invalid for new chars)
        if (gi < 8) begin
          always @(*) begin
            // Default: invalid transition
            next_state_k[gi][gj] = 3'b0;
            next_valid[gi][gj] = 1'b0;

            if (gi < virus_len) begin
              // Standard KMP transition
              automatic int ktemp = gi;
              automatic int c = gj;
              while (ktemp > 0 && virus[ktemp] != c) ktemp = pi[ktemp - 1];
              if (virus[ktemp] == c) ktemp = ktemp + 1;
              // Accept transition if ktemp is within range and not hitting virus fully at a new char
              // (If ktemp == virus_len, appending this char completes a virus, which is invalid.)
              if (ktemp < virus_len) begin
                next_state_k[gi][gj] = ktemp[2:0];
                next_valid[gi][gj] = 1'b1;
              end else begin
                next_state_k[gi][gj] = 3'b0; // don't care
                next_valid[gi][gj] = 1'b0;
              end
            end else begin
              // If in invalid state gi >= virus_len, any new char is invalid.
              next_state_k[gi][gj] = 3'b0;
              next_valid[gi][gj] = 1'b0;
            end
          end
        end
      end
    end
  endgenerate

  // Backtrace logic: reconstruct LCS from dp[0][0][0] while avoiding virus substring
  // We reconstruct at most 8 characters into result[63:0] (LSB = char 0).
  always @(posedge clk) begin
    if (state == BACKTRACE) begin
      if (cycle_cnt == 10'd0) begin
        // Initialize
        result <= 64'b0;
        valid <= (dp[0][0][0] > 0);
        i_next <= 3'b0;
        j_next <= 3'b0;
        k_next <= 3'b0;
      end else if (cycle_cnt <= 10'd8) begin
        automatic int t = cycle_cnt - 1; // which char we are writing (0..7)
        automatic reg [3:0] best_len = dp[i_next][j_next][k_next];

        if (best_len == 0) begin
          // No more matches
          i_next <= i_next;
          j_next <= j_next;
          k_next <= k_next;
          // valid remains as is
        end else begin
          // Try to take a matching character
          if (s1[i_next] == s2[j_next] && next_valid[k_next][s1[i_next]]) begin
            automatic int next_k = next_state_k[k_next][s1[i_next]];
            automatic reg [3:0] cand = dp[i_next+1][j_next+1][next_k] + 1;
            if (cand == best_len) begin
              // Take it
              result <= (result & ~(8'hFF << (t*8))) | ({24'b0, s1[i_next]} << (t*8));
              i_next <= i_next + 1;
              j_next <= j_next + 1;
              k_next <= next_k[2:0];
            end else begin
              // Skip: choose the max of skipping s1 or s2
              automatic reg [3:0] skip_i = dp[i_next+1][j_next][k_next];
              automatic reg [3:0] skip_j = dp[i_next][j_next+1][k_next];
              if (skip_i >= skip_j) begin
                i_next <= i_next + 1;
              end else begin
                j_next <= j_next + 1;
              end
              // k_next unchanged
            end
          end else begin
            // No match or invalid next state, skip
            automatic reg [3:0] skip_i = dp[i_next+1][j_next][k_next];
            automatic reg [3:0] skip_j = dp[i_next][j_next+1][k_next];
            if (skip_i >= skip_j) begin
              i_next <= i_next + 1;
            end else begin
              j_next <= j_next + 1;
            end
            // k_next unchanged
          end
        end
      end
    end
  end

  // Bound timeout: if not done by 600 cycles, force done and valid=0
  always @(posedge clk) begin
    if (cycle_cnt >= MAX_CYCLES && state != DONE) begin
      done <= 1'b1;
      valid <= 1'b0;
      result <= 64'b0;
    end
  end

endmodule