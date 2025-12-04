module max_revenue_calculator (
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0] N,
  input  [9:0] S0, S1, S2, S3, S4,
  output logic [7:0] max_rev,
  output logic done
);

  // State encoding
  localparam IDLE           = 3'd0;
  localparam INIT           = 3'd1;
  localparam PROCESS_SUMS   = 3'd2;
  localparam READ_ROM       = 3'd3;
  localparam UPDATE_MAX     = 3'd4;
  localparam DONE           = 3'd5;

  // Internal signals
  logic [2:0] state_r, state_n;
  logic [7:0] max_rev_r, max_rev_n;

  // Assignment counters (mixed-radix base-N: 0..N-1 for each of N slots)
  // For N=5: need 5 digits base 5 => total 5*log2(5) bits
  logic [4:0] assn [5];
  logic [9:0] top;      // product_{i=0}^{N-1} (N)   = N^N
  logic [9:0] assn_cnt; // counts assignments: 0..top-1
  logic [9:0] top_minus_1; // top - 1 for terminal carry detect
  logic [2:0] N_r;      // registered copy of N for robustness

  // Customer sums
  logic [13:0] sums_r [5];
  logic [13:0] sums_n [5];

  // Prime factor ROM (synchronous read) and pipeline
  // Capacity up to 5000; for sums above limit, we clamp
  logic [7:0] rom_q; // one cycle latency
  logic [13:0] rom_addr; // 0..5000
  logic [6:0] rom_cnt_pipe; // 0..max 6 bits (worst-case prime factor count up to ~50 for <=5000)
  logic [6:0] accum; // accumulating prime counts across customers
  logic [2:0] j;     // customer index
  logic [2:0] j_next;
  logic [2:0] k;     // per-assignment item index
  logic [2:0] k_next;
  logic [1:0] stage; // 2-bit pipeline stage for READ_ROM

  // ROM: precomputed distinct prime factor count for addresses 0..5000
  // Bits per entry: 8 (0..255), which is enough (max distinct prime factors for numbers <=5000 is < 8)
  (*rom_style="block*") logic [7:0] prime_pf_count_rom [0:5000];
  initial begin
    // Simple primality test and distinct prime factor count
    for (int addr = 0; addr <= 5000; addr++) begin
      int n = addr;
      int cnt = 0;
      if (n > 1) begin
        // Count factor 2
        if (n % 2 == 0) begin
          cnt++;
          while (n % 2 == 0) n = n / 2;
        end
        // Odd factors
        for (int f = 3; f * f <= n; f += 2) begin
          if (n % f == 0) begin
            cnt++;
            while (n % f == 0) n = n / f;
          end
        end
        if (n > 1) cnt++; // remaining prime > 1
      end
      prime_pf_count_rom[addr] = cnt[7:0];
    end
  end

  // Clocked storage
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_r    <= IDLE;
      max_rev_r  <= 8'd0;
      N_r        <= 3'd0;
      assn_cnt   <= 10'd0;
      stage      <= 2'd0;
      j          <= 3'd0;
      k          <= 3'd0;
      accum      <= 7'd0;
      rom_cnt_pipe <= 7'd0;
      done       <= 1'b0;
      for (int i = 0; i < 5; i++) sums_r[i] <= 14'd0;
    end else begin
      state_r    <= state_n;
      max_rev_r  <= max_rev_n;
      N_r        <= (state_n == INIT) ? (N >= 3'd1 && N <= 3'd5 ? N : 3'd5) : N_r;
      assn_cnt   <= assn_cnt;
      stage      <= stage;
      j          <= j_next;
      k          <= k_next;
      accum      <= accum;
      rom_cnt_pipe <= rom_cnt_pipe;
      done       <= done;
      for (int i = 0; i < 5; i++) sums_r[i] <= sums_n[i];
    end
  end

  // ROM address latch (address stable for at least 1 cycle)
  always @(posedge clk) begin
    rom_q <= prime_pf_count_rom[rom_addr];
  end

  // Combinational next-state logic
  always_comb begin
    // Defaults
    state_n    = state_r;
    max_rev_n  = max_rev_r;
    done       = 1'b0;
    top        = 10'd1;
    top_minus_1= 10'd0;
    j_next     = j;
    k_next     = k;
    accum      = accum;
    rom_cnt_pipe = rom_cnt_pipe;
    for (int i = 0; i < 5; i++) sums_n[i] = sums_r[i];

    // Start pulse detection: from IDLE on start
    if (state_r == IDLE) begin
      if (start) begin
        state_n = INIT;
      end else begin
        state_n = IDLE;
        done = 1'b0;
      end
    end else if (state_r == INIT) begin
      // Initialize counters and state
      N_r = (N >= 3'd1 && N <= 3'd5) ? N : 3'd5;
      // Build mixed-radix bases: base[i] = N (for all i)
      // Precompute top = N^N, top_minus_1 = top - 1
      top = 10'd1;
      for (int i = 0; i < 5; i++) begin
        assn[i] = 10'd0;
        if (i < N_r) top = top * N_r; // multiply N times
      end
      top_minus_1 = (top > 0) ? (top - 1) : 10'd0;
      assn_cnt = 10'd0;
      for (int i = 0; i < 5; i++) sums_n[i] = 14'd0;
      j_next  = 3'd0;
      k_next  = 3'd0;
      accum   = 7'd0;
      stage   = 2'd0;
      rom_cnt_pipe = 7'd0;
      state_n = PROCESS_SUMS;
      done    = 1'b0;
    end else if (state_r == PROCESS_SUMS) begin
      // Compute sums for current assignment (blocking to finish before advancing)
      for (int i = 0; i < 5; i++) sums_n[i] = 14'd0;
      for (int ii = 0; ii < 5; ii++) begin
        if (ii < N_r) begin
          int cust;
          cust = assn[ii];
          if (cust >= 0 && cust < N_r) begin
            case (ii)
              0: sums_n[cust] = sums_r[cust] + S0;
              1: sums_n[cust] = sums_r[cust] + S1;
              2: sums_n[cust] = sums_r[cust] + S2;
              3: sums_n[cust] = sums_r[cust] + S3;
              4: sums_n[cust] = sums_r[cust] + S4;
            endcase
          end
        end
      end
      // Start ROM reading for sums > 1
      j_next  = 3'd0;
      k_next  = 3'd0;
      accum   = 7'd0;
      stage   = 2'd0;
      rom_cnt_pipe = 7'd0;
      state_n = READ_ROM;
    end else if (state_r == READ_ROM) begin
      // Two-stage pipeline: (1) latch address, (2) accumulate result
      // Stage 0: present address
      if (stage == 2'd0) begin
        if (j < N_r) begin
          int s;
          s = sums_r[j];
          rom_addr = (s > 14'd5000) ? 14'd5000 : (s > 14'd1 ? s : 14'd0);
          // Move to stage 1 (we will add on next cycle)
          stage   = 2'd1;
          j_next  = j;
          k_next  = k;
          accum   = accum;
          rom_cnt_pipe = rom_cnt_pipe;
          state_n = READ_ROM;
        end else begin
          // If all customers read, move to UPDATE_MAX without waiting
          j_next  = j;
          k_next  = k;
          accum   = accum;
          rom_cnt_pipe = rom_cnt_pipe;
          stage   = 2'd0;
          state_n = UPDATE_MAX;
        end
      end else if (stage == 2'd1) begin
        // Stage 1: result available, add to accumulator
        int s;
        s = sums_r[j];
        // Compute whether we should add rom_q (if s > 1) else 0
        if (s > 14'd1) begin
          accum = accum + rom_q;
        end
        // Prepare next customer or finish
        j_next  = (j < N_r - 1) ? (j + 1) : 3'd0;
        k_next  = k;
        stage   = (j < N_r - 1) ? 2'd0 : 2'd0; // next cycle we go back to stage 0 for next j
        rom_cnt_pipe = rom_cnt_pipe;
        state_n = (j < N_r - 1) ? READ_ROM : UPDATE_MAX;
      end else begin
        // Default: no change
        stage = 2'd0;
        j_next = j;
        k_next = k;
        state_n = READ_ROM;
      end
    end else if (state_r == UPDATE_MAX) begin
      if (accum > max_rev_r) begin
        max_rev_n = accum;
      end else begin
        max_rev_n = max_rev_r;
      end

      // Advance mixed-radix counter to next assignment
      if (assn_cnt < top_minus_1) begin
        // Increment base-N counter (0..N-1 per slot)
        assn_cnt = assn_cnt + 1;
        // Compute new digits from assn_cnt
        for (int pos = 0; pos < 5; pos++) begin
          int base;
          base = (pos < N_r) ? N_r : 1; // not used when pos >= N_r
          if (pos < N_r) begin
            int tmp = assn_cnt;
            // extract digit pos by positional value = N^pos
            int place = 1;
            for (int p = 0; p < pos; p++) place = place * N_r;
            assn[pos] = (tmp / place) % N_r;
          end else begin
            assn[pos] = 0;
          end
        end
        // Next assignment: recompute sums
        state_n = PROCESS_SUMS;
        // Clear stage/accum for next iteration
        stage   = 2'd0;
        accum   = 7'd0;
        rom_cnt_pipe = 7'd0;
        // j and k are irrelevant until PROCESS_SUMS; will be reset there
        for (int i = 0; i < 5; i++) sums_n[i] = sums_r[i];
      end else begin
        // All assignments complete
        state_n = DONE;
        done    = 1'b1;
        max_rev_n = max_rev_n;
        // Keep counters; no further changes
      end
    end else if (state_r == DONE) begin
      done = 1'b1;
      if (start) begin
        // If start is held high, re-run; else stay done until start deasserted
        state_n = DONE; // remain until start goes low then high again
      end else begin
        state_n = IDLE;
        done = 1'b0;
      end
      max_rev_n = max_rev_n;
    end else begin
      state_n = IDLE;
      done = 1'b0;
      max_rev_n = max_rev_r;
    end
  end

  // Output assignment (registered)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_rev <= 8'd0;
      done    <= 1'b0;
    end else begin
      max_rev <= max_rev_n;
      done    <= done;
    end
  end

endmodule