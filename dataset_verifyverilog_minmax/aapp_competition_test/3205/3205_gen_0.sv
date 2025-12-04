module min_transactions(
  input clk, // system clock
  input rst_n, // active-low reset
  input start, // pulse high to start computation
  input [2:0] m_in, // number of people (2-6)
  input [3:0] n_in, // number of receipts (0-10)
  input [2:0] a_in, // payer (0-5)
  input [2:0] b_in, // payee (0-5)
  input [9:0] p_in, // amount paid (1-1000)
  input data_valid, // high when receipt data is valid
  output reg [2:0] tx_count, // minimal transaction count (0-5)
  output reg done // high when computation complete
);

  // Local parameters
  parameter MAX_PEOPLE = 6;
  parameter MAX_RECVD = 10;
  parameter NUM_STATES_W = 3;
  parameter IDLE = 3'd0;
  parameter READ = 3'd1;
  parameter COMPUTE_BAL = 3'd2;
  parameter FIND_MIN_TX = 3'd3;
  parameter DONE = 3'd4;

  // Receipt storage
  reg [2:0] rx_a [0:MAX_RECVD-1];
  reg [2:0] rx_b [0:MAX_RECVD-1];
  reg [9:0] rx_p [0:MAX_RECVD-1];

  // Internal state/control
  reg [NUM_STATES_W-1:0] state, next_state;
  reg [3:0] recv_cnt; // received receipts
  reg [3:0] max_recv; // expected receipts (n_in)
  reg [3:0] max_possible_tx; // bounded by m_in-1
  reg [3:0] wait_cnt; // 50-cycle timer after last receipt
  reg [3:0] i; // general loop/index
  reg [3:0] j;

  // Balances and transaction computation
  reg signed [12:0] net [0:MAX_PEOPLE-1];
  reg pos_valid [0:MAX_PEOPLE-1];
  reg neg_valid [0:MAX_PEOPLE-1];
  reg [2:0] pos_list [0:MAX_PEOPLE-1];
  reg [2:0] neg_list [0:MAX_PEOPLE-1];
  reg [2:0] pos_cnt, neg_cnt;

  // Subset elimination buffers
  reg [2:0] credit_idx [0:MAX_PEOPLE-1];
  reg [2:0] debit_idx  [0:MAX_PEOPLE-1];
  reg [2:0] credit_top, debit_top;
  reg credit_mis, debit_mis;
  reg signed [12:0] c_amt_buf, d_amt_buf;
  reg signed [12:0] c_val, d_val;
  reg credit_done, debit_done;

  // Sequential reset and state update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      tx_count <= 3'b0;
      done <= 1'b0;
      recv_cnt <= 4'b0;
      max_recv <= 4'b0;
      max_possible_tx <= 4'b0;
      wait_cnt <= 4'b0;
      // Clear receipts and balances
      for (i = 0; i < MAX_RECVD; i = i + 1) begin
        rx_a[i] <= 3'b0;
        rx_b[i] <= 3'b0;
        rx_p[i] <= 10'b0;
      end
      for (i = 0; i < MAX_PEOPLE; i = i + 1) begin
        net[i] <= 13'b0;
        pos_valid[i] <= 1'b0;
        neg_valid[i] <= 1'b0;
        pos_list[i] <= 3'b0;
        neg_list[i] <= 3'b0;
      end
      pos_cnt <= 3'b0;
      neg_cnt <= 3'b0;
      credit_top <= 3'b0;
      debit_top <= 3'b0;
      credit_mis <= 1'b0;
      debit_mis <= 1'b0;
      c_amt_buf <= 13'b0;
      d_amt_buf <= 13'b0;
      c_val <= 13'b0;
      d_val <= 13'b0;
      credit_done <= 1'b0;
      debit_done <= 1'b0;
    end else begin
      state <= next_state;
      // Output control: done is one-cycle pulse in DONE state
      if (state == FIND_MIN_TX) begin
        done <= 1'b0;
      end else if (state == DONE) begin
        done <= 1'b1;
      end else begin
        done <= 1'b0;
      end

      // Default clears for per-state signals
      if (state == IDLE) begin
        recv_cnt <= 4'b0;
        max_recv <= 4'b0;
        max_possible_tx <= 4'b0;
        wait_cnt <= 4'b0;
        tx_count <= 3'b0;
        for (i = 0; i < MAX_PEOPLE; i = i + 1) begin
          pos_valid[i] <= 1'b0;
          neg_valid[i] <= 1'b0;
        end
        for (i = 0; i < MAX_PEOPLE; i = i + 1) begin
          net[i] <= 13'b0;
        end
      end

      if (state == READ) begin
        // Accept up to 10 receipts when data_valid is high
        if (data_valid && recv_cnt < MAX_RECVD) begin
          rx_a[recv_cnt] <= a_in;
          rx_b[recv_cnt] <= b_in;
          rx_p[recv_cnt] <= p_in;
          recv_cnt <= recv_cnt + 1;
        end

        // After each newly received receipt, check if all expected receipts are in
        if (recv_cnt == max_recv) begin
          // Start bounded wait after last receipt is received
          if (wait_cnt == 4'd0) begin
            wait_cnt <= 4'd1;
          end else if (wait_cnt < 4'd50) begin
            wait_cnt <= wait_cnt + 1;
          end else begin
            wait_cnt <= 4'd50; // clamp
          end
        end
      end

      if (state == COMPUTE_BAL) begin
        // Already computed via comb logic into wires during previous cycle
        for (i = 0; i < MAX_PEOPLE; i = i + 1) begin
          net[i] <= net[i]; // keep stable
          pos_valid[i] <= pos_valid[i];
          neg_valid[i] <= neg_valid[i];
        end
        pos_cnt <= pos_cnt;
        neg_cnt <= neg_cnt;
      end

      if (state == FIND_MIN_TX) begin
        // Subset elimination via greedy matching in-place, bounded by ~m_in-1 txns
        // Initialize from lists on first cycle
        if (credit_top == 3'd0 && debit_top == 3'd0) begin
          for (i = 0; i < MAX_PEOPLE; i = i + 1) begin
            if (pos_valid[i]) begin
              credit_idx[credit_top] <= pos_list[i];
              credit_top <= credit_top + 1;
            end
            if (neg_valid[i]) begin
              debit_idx[debit_top] <= neg_list[i];
              debit_top <= debit_top + 1;
            end
          end
          credit_mis <= 1'b0;
          debit_mis <= 1'b0;
          c_amt_buf <= 13'b0;
          d_amt_buf <= 13'b0;
          c_val <= 13'b0;
          d_val <= 13'b0;
          credit_done <= 1'b0;
          debit_done <= 1'b0;
          tx_count <= 3'b0; // will be set next cycle when complete
        end else begin
          // Pop top elements if not already buffered
          if (!credit_mis) begin
            if (credit_top > 3'd0) begin
              credit_top <= credit_top - 1;
              c_amt_buf <= net[credit_idx[credit_top - 1]];
              c_val <= net[credit_idx[credit_top - 1]];
              credit_done <= 1'b0;
              credit_mis <= 1'b1;
            end else begin
              credit_done <= 1'b1;
            end
          end
          if (!debit_mis) begin
            if (debit_top > 3'd0) begin
              debit_top <= debit_top - 1;
              d_amt_buf <= net[debit_idx[debit_top - 1]]; // negative value
              d_val <= net[debit_idx[debit_top - 1]];
              debit_done <= 1'b0;
              debit_mis <= 1'b1;
            end else begin
              debit_done <= 1'b1;
            end
          end

          // If both sides have values, perform subtraction
          if (credit_mis && debit_mis && !credit_done && !debit_done) begin
            if (c_val > 0 && d_val < 0) begin
              if (c_val > (-d_val)) begin
                c_val <= c_val - (-d_val);
                debit_done <= 1'b0; // debit satisfied
                debit_mis <= 1'b0;
              end else if (c_val < (-d_val)) begin
                d_val <= d_val + c_val; // stays negative, amount = |d| - c
                credit_done <= 1'b0;    // credit satisfied
                credit_mis <= 1'b0;
              end else begin
                // exact match: both satisfied
                d_val <= 13'b0;
                c_val <= 13'b0;
                credit_done <= 1'b0;
                debit_done <= 1'b0;
                credit_mis <= 1'b0;
                debit_mis <= 1'b0;
              end
              // Count one transaction
              tx_count <= tx_count + 1;
            end else begin
              // Shouldn't happen in well-formed balances, but guard anyway
              credit_mis <= 1'b0;
              debit_mis <= 1'b0;
              credit_done <= 1'b1;
              debit_done <= 1'b1;
            end
          end

          // If one side is depleted, try to bring next value into buffer
          if ((!credit_mis && !credit_done) || (!debit_mis && !debit_done)) begin
            // Leave to next cycle to pop new entries
          end

          // Completion condition: both sides fully processed
          if (credit_done && debit_done) begin
            // Done: no extra action here; next_state logic handles state transition
          end
        end
      end
    end
  end

  // Compute balances and pos/neg lists (combinational, used in COMPUTE_BAL state)
  reg signed [13:0] temp_sum [0:MAX_PEOPLE-1];
  always @(*) begin
    // Clear temporary sums
    for (i = 0; i < MAX_PEOPLE; i = i + 1) begin
      temp_sum[i] = 14'b0;
    end
    // Accumulate amounts from received receipts
    for (i = 0; i < MAX_RECVD; i = i + 1) begin
      if (i < recv_cnt) begin
        // Clamp indices to avoid out-of-range if b_in >= m_in
        if (rx_a[i] < m_in) begin
          temp_sum[rx_a[i]] = temp_sum[rx_a[i]] + $signed({1'b0, rx_p[i]});
        end
        if (rx_b[i] < m_in) begin
          temp_sum[rx_b[i]] = temp_sum[rx_b[i]] - $signed({1'b0, rx_p[i]});
        end
      end
    end
    // Create pos/neg lists and signed nets
    pos_cnt = 3'd0;
    neg_cnt = 3'd0;
    for (i = 0; i < MAX_PEOPLE; i = i + 1) begin
      if (i < m_in) begin
        net[i] = temp_sum[i][12:0]; // signed 13-bit
        if (net[i] > 13'sd0) begin
          pos_list[pos_cnt] = i;
          pos_cnt = pos_cnt + 1;
        end else if (net[i] < 13'sd0) begin
          neg_list[neg_cnt] = i;
          neg_cnt = neg_cnt + 1;
        end
      end else begin
        net[i] = 13'sd0;
      end
    end
    // Set valid flags for people within m_in
    for (i = 0; i < MAX_PEOPLE; i = i + 1) begin
      if (i < m_in) begin
        pos_valid[i] = (net[i] > 13'sd0);
        neg_valid[i] = (net[i] < 13'sd0);
      end else begin
        pos_valid[i] = 1'b0;
        neg_valid[i] = 1'b0;
      end
    end
    // max_possible_tx = max(0, m_in-1), bounded by 5
    if (m_in >= 3'd2) begin
      max_possible_tx = (m_in - 3'd1);
    end else begin
      max_possible_tx = 3'd0;
    end
  end

  // State machine next-state logic
  always @(*) begin
    // Defaults
    next_state = state;
    max_recv = n_in;
    case (state)
      IDLE: begin
        if (start) begin
          if (m_in < 2) begin
            next_state = DONE;
          end else begin
            next_state = READ;
          end
        end else begin
          next_state = IDLE;
        end
      end

      READ: begin
        if (m_in < 2) begin
          next_state = DONE; // safety; shouldn't happen due to IDLE check
        end else if (recv_cnt == max_recv && wait_cnt >= 4'd50) begin
          next_state = COMPUTE_BAL;
        end else begin
          next_state = READ;
        end
      end

      COMPUTE_BAL: begin
        next_state = FIND_MIN_TX;
      end

      FIND_MIN_TX: begin
        if (credit_done && debit_done) begin
          next_state = DONE;
        end else begin
          next_state = FIND_MIN_TX;
        end
      end

      DONE: begin
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end
endmodule