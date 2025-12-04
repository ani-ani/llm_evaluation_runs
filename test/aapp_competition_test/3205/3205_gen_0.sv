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

  // State encoding
  localparam IDLE        = 3'd0;
  localparam READ        = 3'd1;
  localparam COMPUTE_BAL = 3'd2;
  localparam FIND_MIN_TX = 3'd3;
  localparam DONE_STATE  = 3'd4;

  reg [2:0] state, next_state;

  // Internal registers
  reg [2:0] m_reg;           // number of people
  reg [3:0] n_reg;           // number of receipts
  reg [3:0] rcnt;            // receipts counted

  // Balances: signed 13-bit per person (0..5)
  reg signed [12:0] balance [0:5];
  reg signed [12:0] balance_next [0:5];

  // Latched inputs for each receipt (simple streaming, no storage of full list needed)
  // We update balances on the fly during READ

  // For subset DP
  reg [5:0] person_mask;           // mask for m_reg persons (LSBs)
  reg [5:0] balances_zero_mask;    // tracks which indices are effectively used (same as person_mask)

  // DP arrays: up to 2^6 = 64 subsets
  reg        subset_valid    [0:63]; // whether subset is a subset of active persons
  reg signed [12:0] subset_sum[0:63];
  reg  [2:0] best_dp         [0:63]; // minimum internal transactions for subset

  // Iteration control for DP computation
  reg [5:0] dp_idx;
  reg [5:0] cycle_cnt; // to ensure bounded time if needed (not strictly necessary but included)

  integer i;

  // Combinational: next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          if (m_in < 2)
            next_state = DONE_STATE;
          else if (n_in == 0)
            next_state = COMPUTE_BAL; // balances already zeroed
          else
            next_state = READ;
        end
      end
      READ: begin
        // Move to compute when all receipts received
        if (rcnt == n_reg && n_reg != 0)
          next_state = COMPUTE_BAL;
      end
      COMPUTE_BAL: begin
        next_state = FIND_MIN_TX;
      end
      FIND_MIN_TX: begin
        // When DP over all subsets complete, go DONE
        if (dp_idx == 6'd63)
          next_state = DONE_STATE;
      end
      DONE_STATE: begin
        // one cycle done pulse, then back to IDLE
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential state and main registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      done       <= 1'b0;
      tx_count   <= 3'd0;
      m_reg      <= 3'd0;
      n_reg      <= 4'd0;
      rcnt       <= 4'd0;
      dp_idx     <= 6'd0;
      cycle_cnt  <= 6'd0;
      person_mask <= 6'd0;
      balances_zero_mask <= 6'd0;
      for (i = 0; i < 6; i = i + 1) begin
        balance[i] <= 13'sd0;
      end
      for (i = 0; i < 64; i = i + 1) begin
        subset_valid[i] <= 1'b0;
        subset_sum[i]   <= 13'sd0;
        best_dp[i]      <= 3'd0;
      end
    end else begin
      state <= next_state;

      // Default outputs
      done <= 1'b0;

      case (state)
        IDLE: begin
          // Clear all on new start
          if (start) begin
            tx_count  <= 3'd0;
            m_reg     <= m_in;
            n_reg     <= n_in;
            rcnt      <= 4'd0;
            dp_idx    <= 6'd0;
            cycle_cnt <= 6'd0;
            // Set person_mask for m_in people
            if (m_in >= 3'd6)      person_mask <= 6'b111111;
            else if (m_in == 3'd5) person_mask <= 6'b00111111 >> 1; // 5 LSBs => 011111
            else if (m_in == 3'd4) person_mask <= 6'b0001111;
            else if (m_in == 3'd3) person_mask <= 6'b0000111;
            else if (m_in == 3'd2) person_mask <= 6'b0000011;
            else                   person_mask <= 6'b0000000;

            for (i = 0; i < 6; i = i + 1) begin
              balance[i] <= 13'sd0;
            end

            // If m_in < 2: immediate done next cycle (handled in DONE_STATE via next_state)
          end
        end

        READ: begin
          // Accept up to n_reg receipts; update balances on the fly
          if (data_valid && rcnt < n_reg) begin
            // Only consider if payer/payee indices within m_reg
            if (a_in < m_reg) begin
              balance[a_in] <= balance[a_in] - $signed({3'b000, p_in});
            end
            if (b_in < m_reg) begin
              balance[b_in] <= balance[b_in] + $signed({3'b000, p_in});
            end
            rcnt <= rcnt + 4'd1;
          end
        end

        COMPUTE_BAL: begin
          // Build masks based on m_reg
          balances_zero_mask <= person_mask;

          // Initialize subset DP bases
          for (i = 0; i < 64; i = i + 1) begin
            subset_valid[i] <= 1'b0;
            subset_sum[i]   <= 13'sd0;
            best_dp[i]      <= 3'd7; // large init (> max 5)
          end

          // subset 0
          subset_valid[0] <= 1'b1;
          subset_sum[0]   <= 13'sd0;
          best_dp[0]      <= 3'd0;

          // Initialize dp_idx for FIND_MIN_TX
          dp_idx    <= 6'd1;
          cycle_cnt <= 6'd0;
        end

        FIND_MIN_TX: begin
          cycle_cnt <= cycle_cnt + 6'd1;

          // Process one subset per cycle for bounded time (64 subsets)
          if (dp_idx < 6'd64) begin
            // Only consider subsets within person_mask
            if ((dp_idx & ~person_mask) == 0) begin
              subset_valid[dp_idx] <= 1'b1;

              // Compute subset_sum incrementally from sub = s without lsb
              // Use lowest set bit method
              // s' = s & (s - 1); bit = s ^ s'; index = position(bit)
              // Implement combinationally here
              reg [5:0] s;
              reg [5:0] s_wo_lsb;
              reg [5:0] lsb_mask;
              reg [2:0] idx;
              reg signed [12:0] sum_tmp;
              reg [2:0] best_tmp;
              integer k;

              s = dp_idx[5:0];
              s_wo_lsb = s & (s - 1'b1);
              lsb_mask = s ^ s_wo_lsb;

              // Find index of lsb_mask
              idx = 3'd0;
              for (k = 0; k < 6; k = k + 1) begin
                if (lsb_mask[k]) idx = k[2:0];
              end

              sum_tmp = subset_sum[s_wo_lsb] + balance[idx];
              subset_sum[dp_idx] <= sum_tmp;

              // DP: find minimal transactions for subset dp_idx
              // For subset with total sum == 0, we can partition into zero-sum groups
              // Using recurrence: dp[S] = min over non-empty proper T subset of S, sum(T)==0: dp[S\T] + (1 for T)
              if (sum_tmp == 13'sd0) begin
                // At least the whole subset can be 1 group
                best_tmp = 3'd1;
              end else begin
                best_tmp = 3'd7; // large init
              end

              // Enumerate proper non-empty subsets T of S: T = (s-1)&s loop
              reg [5:0] t;
              reg [5:0] rem;
              reg [2:0] cand;
              t = (s - 1'b1) & s;
              while (t != 6'd0) begin
                // only if t is valid subset of persons
                if ((t & ~person_mask) == 0) begin
                  if (subset_sum[t] == 13'sd0 && best_dp[t] != 3'd7 && subset_valid[s ^ t]) begin
                    rem = s ^ t;
                    cand = best_dp[rem] + 3'd1;
                    if (cand < best_tmp)
                      best_tmp = cand;
                  end
                end
                t = (t - 1'b1) & s;
              end

              best_dp[dp_idx] <= best_tmp;
            end else begin
              subset_valid[dp_idx] <= 1'b0;
              subset_sum[dp_idx]   <= 13'sd0;
              best_dp[dp_idx]      <= 3'd7;
            end

            // advance index
            dp_idx <= dp_idx + 6'd1;
          end
        end

        DONE_STATE: begin
          // Compute tx_count from DP result or special cases
          if (m_reg < 2) begin
            tx_count <= 3'd0;
          end else begin
            // Build full mask of active persons
            reg [5:0] full_mask;
            full_mask = person_mask;

            // If total sum != 0 (should not happen for consistent input), force 0
            if (subset_sum[full_mask] != 13'sd0) begin
              tx_count <= 3'd0;
            end else begin
              // best_dp[full_mask] groups, transactions = groups - 1 (if >0)
              if (best_dp[full_mask] == 3'd7 || best_dp[full_mask] == 3'd0)
                tx_count <= 3'd0;
              else if (best_dp[full_mask] > 3'd0)
                tx_count <= (best_dp[full_mask] - 3'd1 <= 3'd5) ? (best_dp[full_mask] - 3'd1) : 3'd5;
              else
                tx_count <= 3'd0;
            end
          end

          done <= 1'b1; // pulse for one cycle

          // Prepare for next IDLE by not altering state here; state machine transitions next
        end

        default: ;
      endcase
    end
  end

endmodule