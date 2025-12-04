module min_transactions(
  input clk,
  input rst_n,
  input start,
  input [2:0] m_in,
  input [3:0] n_in,
  input [2:0] a_in,
  input [2:0] b_in,
  input [9:0] p_in,
  input data_valid,
  output reg [2:0] tx_count,
  output reg done
);

  typedef enum reg [2:0] {IDLE, READ, COMPUTE_BAL, FIND_MIN_TX, DONE_ST} state_t;
  state_t state;

  reg signed [12:0] net_balance [0:5];
  reg [3:0] receipt_cnt;
  reg signed [12:0] nonzero_balances [0:5];
  reg [2:0] k_count;
  reg [5:0] current_valid;
  reg [2:0] min_tx;
  reg [5:0] best_mask;
  reg [2:0] best_size;
  reg found_subset;
  reg first_cycle;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      tx_count <= 0;
      receipt_cnt <= 0;
      best_mask <= 0;
      best_size <= 0;
      found_subset <= 0;
      first_cycle <= 0;
      foreach (net_balance[i]) net_balance[i] <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          tx_count <= 0;
          if (start) begin
            if (m_in < 2) begin
              tx_count <= 0;
              done <= 1;
              state <= DONE_ST;
            end else begin
              state <= READ;
              receipt_cnt <= 0;
              foreach (net_balance[i]) net_balance[i] <= 0;
            end
          end
        end

        READ: begin
          done <= 0;
          if (data_valid && (receipt_cnt < n_in)) begin
            if (b_in < m_in) begin
              net_balance[a_in] <= net_balance[a_in] - p_in;
              net_balance[b_in] <= net_balance[b_in] + p_in;
            end
            receipt_cnt <= receipt_cnt + 1;
          end
          if (receipt_cnt >= n_in) state <= COMPUTE_BAL;
        end

        COMPUTE_BAL: begin
          k_count <= 0;
          foreach (net_balance[i]) begin
            if (net_balance[i] != 0) begin
              nonzero_balances[k_count] <= net_balance[i];
              k_count <= k_count + 1;
            end
          end
          state <= FIND_MIN_TX;
          first_cycle <= 1;
        end

        FIND_MIN_TX: begin
          if (first_cycle) begin
            current_valid <= (6'(1) << k_count) - 1;
            min_tx <= (k_count > 1) ? (k_count - 1) : 0;
            first_cycle <= 0;
            best_size <= 0;
            best_mask <= 0;
            found_subset <= 0;
          end else begin
            if (best_size >=2) begin
              min_tx <= min_tx - (best_size - 1);
              current_valid <= current_valid & ~best_mask;
            end
            if (best_size <2 || current_valid == 0) begin
              tx_count <= min_tx;
              done <= 1;
              state <= DONE_ST;
            end
          end
        end

        DONE_ST: begin
          done <= 0;
          state <= IDLE;
        end
      endcase
    end
  end

  always_comb begin
    found_subset = 0;
    best_size = 0;
    best_mask = 0; 
    for (int i=1; i < 64; i=i+1) begin
      if ((i & current_valid) != i) continue;
      automatic int popcount = $countbits(i,1);
      automatic logic signed [12:0] sum_val = 0;
      for (int j=0; j<6; j=j+1) begin
        if (i[j]) sum_val += (j < k_count) ? nonzero_balances[j] : 0;
      end
      if (sum_val == 13'sh0 && popcount > best_size) begin
        found_subset = 1;
        best_size = popcount;
        best_mask = i;
      end else if (sum_val == 13'sh0 && popcount == best_size && i > best_mask) begin
        best_mask = i;
      end
    end
  end
endmodule