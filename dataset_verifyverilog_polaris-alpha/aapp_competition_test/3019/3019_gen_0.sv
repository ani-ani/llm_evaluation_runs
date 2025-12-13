module max_revenue_calculator(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [2:0]  N,
  input  logic [9:0]  S0,
  input  logic [9:0]  S1,
  input  logic [9:0]  S2,
  input  logic [9:0]  S3,
  input  logic [9:0]  S4,
  output logic [7:0]  max_rev,
  output logic        done
);

  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------
  localparam int MAX_N       = 5;
  localparam int MAX_SUM     = 5000; // ROM address range 0..5000
  localparam int MAX_ASSIGN  = 3125; // 5^5 max combinations (N=5)

  // FSM states
  typedef enum logic [2:0] {
    IDLE          = 3'd0,
    INIT          = 3'd1,
    COMPUTE_SUMS  = 3'd2,
    PRIME_LOOKUP  = 3'd3,
    UPDATE_MAX    = 3'd4,
    DONE          = 3'd5
  } state_t;

  state_t state, next_state;

  // ------------------------------------------------------------
  // Signals
  // ------------------------------------------------------------

  // Effective N (limit to 1..MAX_N, treat 0 as 1 to avoid degenerate case)
  logic [2:0] N_eff;

  // Base-N counter for assignments; length MAX_N (5) digits
  logic [2:0] assign_digit [0:MAX_N-1];  // each digit in 0..N_eff-1
  logic       last_assignment;

  // Per-customer sums (up to MAX_N customers)
  logic [12:0] cust_sum    [0:MAX_N-1]; // up to 5000
  logic [12:0] next_cust_sum [0:MAX_N-1];

  // Index for iterating pieces during COMPUTE_SUMS
  logic [2:0] piece_idx;
  logic [2:0] cust_idx;

  // ROM outputs for prime factor counts per customer
  logic [7:0] prime_cnt [0:MAX_N-1];

  // Accumulated prime count for current assignment
  logic [11:0] curr_total_prime;
  logic [11:0] next_curr_total_prime;

  // Max revenue
  logic [11:0] max_rev_int;

  // Control flags
  logic init_assign;       // initialize assignment counter
  logic inc_assign;        // increment assignment counter
  logic clear_sums;        // clear cust_sum
  logic compute_done;      // all pieces processed for this assignment
  logic prime_lookup_done; // ROM read complete (same-cycle comb)

  // ------------------------------------------------------------
  // N effective
  // ------------------------------------------------------------
  always_comb begin
    if (N == 3'd0)
      N_eff = 3'd1;
    else if (N > MAX_N[2:0])
      N_eff = MAX_N[2:0];
    else
      N_eff = N;
  end

  // ------------------------------------------------------------
  // Base-N_eff assignment counter (length MAX_N, only 0..N_eff-1 used)
  // ------------------------------------------------------------
  integer i_cnt;

  // Increment logic (combinational)
  logic [2:0] assign_digit_next [0:MAX_N-1];
  logic       last_assignment_next;

  always_comb begin
    // Default: hold
    for (i_cnt = 0; i_cnt < MAX_N; i_cnt = i_cnt + 1) begin
      assign_digit_next[i_cnt] = assign_digit[i_cnt];
    end
    last_assignment_next = 1'b0;

    if (init_assign) begin
      // reset all digits to 0
      for (i_cnt = 0; i_cnt < MAX_N; i_cnt = i_cnt + 1) begin
        assign_digit_next[i_cnt] = 3'd0;
      end
      last_assignment_next = (N_eff == 3'd1) ? 1'b1 : 1'b0; // special when only one customer and one digit? still handle by logic
    end
    else if (inc_assign) begin
      // ripple increment in base N_eff over first N_eff digits (pieces up to N_eff, but we keep fixed LEN=MAX_N; only first N_eff used)
      int d;
      logic carry;
      carry = 1'b1;
      for (d = 0; d < MAX_N; d = d + 1) begin
        if (d < N_eff) begin
          if (carry) begin
            if (assign_digit[d] == (N_eff - 1)) begin
              assign_digit_next[d] = 3'd0;
              carry = 1'b1;
            end else begin
              assign_digit_next[d] = assign_digit[d] + 3'd1;
              carry = 1'b0;
            end
          end
        end else begin
          // digits beyond N_eff kept 0
          assign_digit_next[d] = 3'd0;
        end
      end
      // if still carry after highest used digit -> wrapped around -> last assignment was previous
      if (carry) begin
        last_assignment_next = 1'b1;
      end
    end
  end

  // Sequential update of assignment digits and last_assignment
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i_cnt = 0; i_cnt < MAX_N; i_cnt = i_cnt + 1) begin
        assign_digit[i_cnt] <= 3'd0;
      end
      last_assignment <= 1'b0;
    end else begin
      for (i_cnt = 0; i_cnt < MAX_N; i_cnt = i_cnt + 1) begin
        assign_digit[i_cnt] <= assign_digit_next[i_cnt];
      end
      last_assignment <= last_assignment_next;
    end
  end

  // ------------------------------------------------------------
  // Compute sums: iterate over pieces using current assignment
  // ------------------------------------------------------------
  // clear_sums asserted to initialize cust_sum to 0 before processing pieces

  integer i_sum;

  // S array view
  logic [9:0] S_arr [0:MAX_N-1];
  always_comb begin
    S_arr[0] = S0;
    S_arr[1] = S1;
    S_arr[2] = S2;
    S_arr[3] = S3;
    S_arr[4] = S4;
  end

  // Next cust_sum computation (sequential piece accumulation)
  always_comb begin
    // default: hold
    for (i_sum = 0; i_sum < MAX_N; i_sum = i_sum + 1) begin
      next_cust_sum[i_sum] = cust_sum[i_sum];
    end

    if (clear_sums) begin
      for (i_sum = 0; i_sum < MAX_N; i_sum = i_sum + 1) begin
        next_cust_sum[i_sum] = 13'd0;
      end
    end else begin
      // when in COMPUTE_SUMS and not clear_sums, add current piece to its assigned customer
      if (state == COMPUTE_SUMS) begin
        if (piece_idx < N_eff) begin
          // assigned customer index from assign_digit[piece_idx]
          logic [2:0] cidx;
          cidx = assign_digit[piece_idx];
          if (cidx < N_eff) begin
            next_cust_sum[cidx] = cust_sum[cidx] + S_arr[piece_idx];
          end
        end
      end
    end
  end

  // piece_idx and cust_sum sequential update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      piece_idx <= 3'd0;
      for (i_sum = 0; i_sum < MAX_N; i_sum = i_sum + 1) begin
        cust_sum[i_sum] <= 13'd0;
      end
    end else begin
      // update cust_sum
      for (i_sum = 0; i_sum < MAX_N; i_sum = i_sum + 1) begin
        cust_sum[i_sum] <= next_cust_sum[i_sum];
      end

      // piece_idx update
      if (state == INIT) begin
        piece_idx <= 3'd0;
      end else if (state == COMPUTE_SUMS) begin
        if (piece_idx < N_eff) begin
          piece_idx <= piece_idx + 3'd1;
        end
      end else begin
        piece_idx <= 3'd0;
      end
    end
  end

  // compute_done: when all N_eff pieces processed
  always_comb begin
    compute_done = (state == COMPUTE_SUMS) && (piece_idx >= N_eff);
  end

  // ------------------------------------------------------------
  // Prime factor count ROM (combinational)
  // ------------------------------------------------------------
  function automatic [7:0] prime_factor_count(input int unsigned val);
    int v;
    int count;
    int p;
    begin
      if (val <= 1) begin
        prime_factor_count = 8'd0;
      end else begin
        v = val;
        count = 0;
        // count distinct prime factors
        // factor 2
        if ((v % 2) == 0) begin
          count++;
          while ((v % 2) == 0) v = v / 2;
        end
        // odd factors
        p = 3;
        while (p*p <= v) begin
          if ((v % p) == 0) begin
            count++;
            while ((v % p) == 0) v = v / p;
          end
          p = p + 2;
        end
        if (v > 1) count++;
        prime_factor_count = count[7:0];
      end
    end
  endfunction

  integer i_pf;

  always_comb begin
    for (i_pf = 0; i_pf < MAX_N; i_pf = i_pf + 1) begin
      if (i_pf < N_eff)
        prime_cnt[i_pf] = prime_factor_count(cust_sum[i_pf]);
      else
        prime_cnt[i_pf] = 8'd0;
    end
    prime_lookup_done = 1'b1; // purely combinational lookup
  end

  // ------------------------------------------------------------
  // Accumulate prime counts for current assignment
  // ------------------------------------------------------------
  always_comb begin
    next_curr_total_prime = curr_total_prime;
    if (state == PRIME_LOOKUP) begin
      // sum all N_eff customers' prime_cnt
      int k;
      int sum_tmp;
      sum_tmp = 0;
      for (k = 0; k < MAX_N; k = k + 1) begin
        if (k < N_eff) begin
          sum_tmp = sum_tmp + prime_cnt[k];
        end
      end
      next_curr_total_prime = sum_tmp[11:0];
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      curr_total_prime <= 12'd0;
    end else begin
      if (state == INIT)
        curr_total_prime <= 12'd0;
      else
        curr_total_prime <= next_curr_total_prime;
    end
  end

  // ------------------------------------------------------------
  // Max revenue tracking
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_rev_int <= 12'd0;
    end else begin
      if (state == IDLE && start)
        max_rev_int <= 12'd0;
      else if (state == UPDATE_MAX) begin
        if (curr_total_prime > max_rev_int)
          max_rev_int <= curr_total_prime;
      end
    end
  end

  // Output clamp to 8 bits (enough for problem scale)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_rev <= 8'd0;
    end else begin
      max_rev <= max_rev_int[7:0];
    end
  end

  // ------------------------------------------------------------
  // FSM: next state logic
  // ------------------------------------------------------------
  always_comb begin
    next_state   = state;
    init_assign  = 1'b0;
    inc_assign   = 1'b0;
    clear_sums   = 1'b0;

    case (state)
      IDLE: begin
        if (start) begin
          next_state  = INIT;
        end
      end

      INIT: begin
        // initialize assignment counter and sums
        init_assign = 1'b1;
        clear_sums  = 1'b1;
        next_state  = COMPUTE_SUMS;
      end

      COMPUTE_SUMS: begin
        if (compute_done) begin
          next_state = PRIME_LOOKUP;
        end
      end

      PRIME_LOOKUP: begin
        if (prime_lookup_done) begin
          next_state = UPDATE_MAX;
        end
      end

      UPDATE_MAX: begin
        // After updating max, move to next assignment or finish
        if (last_assignment) begin
          next_state = DONE;
        end else begin
          // increment assignment pattern and recompute sums
          inc_assign = 1'b1;
          clear_sums = 1'b1;
          next_state = COMPUTE_SUMS;
        end
      end

      DONE: begin
        // stay in DONE until start goes low then high again
        if (!start)
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // ------------------------------------------------------------
  // FSM state register and done signal
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      done <= 1'b0;
    else
      done <= (state == DONE);
  end

endmodule