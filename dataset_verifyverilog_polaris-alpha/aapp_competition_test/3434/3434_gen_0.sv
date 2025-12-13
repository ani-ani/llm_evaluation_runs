module explosion_probability(
  input clk,
  input rst_n,
  input start,
  input [1:0] num_my_minions,
  input [1:0] num_opp_minions,
  input [1:0] my_health_1,
  input [1:0] my_health_2,
  input [1:0] opp_health_1,
  input [1:0] opp_health_2,
  input [1:0] d,
  output reg [31:0] prob,
  output reg done
);

  // Q16.16 constants
  localparam [31:0] ONE_Q16_16 = 32'h00010000;

  // State encoding
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_INIT      = 3'd1,
    S_ENUM      = 3'd2,
    S_CHECK     = 3'd3,
    S_NEXT      = 3'd4,
    S_FINISH    = 3'd5
  } state_t;

  state_t state, next_state;

  // Latched inputs
  reg [1:0] l_num_my_minions;
  reg [1:0] l_num_opp_minions;
  reg [1:0] l_my_health_1;
  reg [1:0] l_my_health_2;
  reg [1:0] l_opp_health_1;
  reg [1:0] l_opp_health_2;
  reg [1:0] l_d;

  // Sequence index and total sequences
  // Max d = 3, each step chooses among up to 4 targets => 4^3 = 64 combinations
  reg [5:0] seq_idx;          // current sequence index
  reg [5:0] total_seq_minus1; // total_sequences - 1

  // Working health registers for simulation
  reg [2:0] my1_h;
  reg [2:0] my2_h;
  reg [2:0] opp1_h;
  reg [2:0] opp2_h;
  reg [2:0] step_cnt;

  // Probability accumulators
  reg [31:0] success_prob;
  reg [31:0] per_seq_prob;

  // Temporary
  reg [31:0] tmp_prob;

  // Combinational target count and related values
  reg [2:0] total_alive_init;
  reg [2:0] total_alive_curr;
  reg [1:0] target_sel;

  // Compute alive minions at initialization
  always @(*) begin
    total_alive_init = 3'd0;

    // Opponent minions
    if (l_num_opp_minions > 0 && l_opp_health_1 != 2'd0)
      total_alive_init = total_alive_init + 3'd1;
    if (l_num_opp_minions > 1 && l_opp_health_2 != 2'd0)
      total_alive_init = total_alive_init + 3'd1;

    // Our minions
    if (l_num_my_minions > 0 && l_my_health_1 != 2'd0)
      total_alive_init = total_alive_init + 3'd1;
    if (l_num_my_minions > 1 && l_my_health_2 != 2'd0)
      total_alive_init = total_alive_init + 3'd1;
  end

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= S_IDLE;
    else
      state <= next_state;
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end

      S_INIT: begin
        // Move to enumeration or directly finish if no opponent minions or sequence count zero
        if (l_d == 0 || total_seq_minus1 == 6'd0)
          next_state = S_FINISH;
        else
          next_state = S_ENUM;
      end

      S_ENUM: begin
        // Initialize per-sequence simulation
        next_state = S_CHECK;
      end

      S_CHECK: begin
        // Apply one damage step per cycle until step_cnt == l_d
        if (step_cnt == l_d)
          next_state = S_NEXT;
        else
          next_state = S_CHECK;
      end

      S_NEXT: begin
        if (seq_idx == total_seq_minus1)
          next_state = S_FINISH;
        else
          next_state = S_ENUM;
      end

      S_FINISH: begin
        // Stay until next start
        if (!start)
          next_state = S_IDLE;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Main sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      l_num_my_minions  <= 2'd0;
      l_num_opp_minions <= 2'd0;
      l_my_health_1     <= 2'd0;
      l_my_health_2     <= 2'd0;
      l_opp_health_1    <= 2'd0;
      l_opp_health_2    <= 2'd0;
      l_d               <= 2'd0;

      seq_idx           <= 6'd0;
      total_seq_minus1  <= 6'd0;

      my1_h             <= 3'd0;
      my2_h             <= 3'd0;
      opp1_h            <= 3'd0;
      opp2_h            <= 3'd0;
      step_cnt          <= 3'd0;

      success_prob      <= 32'd0;
      per_seq_prob      <= 32'd0;
      tmp_prob          <= 32'd0;

      prob              <= 32'd0;
      done              <= 1'b0;
    end else begin
      done <= 1'b0;

      case (state)
        S_IDLE: begin
          if (start) begin
            // Latch inputs
            l_num_my_minions  <= num_my_minions;
            l_num_opp_minions <= num_opp_minions;
            l_my_health_1     <= my_health_1;
            l_my_health_2     <= my_health_2;
            l_opp_health_1    <= opp_health_1;
            l_opp_health_2    <= opp_health_2;
            l_d               <= d;

            seq_idx           <= 6'd0;
            success_prob      <= 32'd0;

            // total_seq_minus1 computed in S_INIT once total_alive_init known
          end
        end

        S_INIT: begin
          // Handle edge cases
          if (l_d == 0) begin
            // No damage: probability = 1 if opponents already dead, else 0
            if ((l_num_opp_minions == 0) ||
                ((l_num_opp_minions == 1) && (l_opp_health_1 == 0)) ||
                ((l_num_opp_minions == 2) && (l_opp_health_1 == 0) && (l_opp_health_2 == 0))) begin
              prob <= ONE_Q16_16;
            end else begin
              prob <= 32'd0;
            end
            total_seq_minus1 <= 6'd0;
          end else begin
            // Compute total sequences: (total_alive_init ^ l_d)
            // Since max l_d <= 3, we can explicit compute
            if (total_alive_init == 0) begin
              // No targets => no valid damage; treat as 1 sequence of doing nothing
              total_seq_minus1 <= 6'd0; // total_seq = 1
            end else begin
              case (l_d)
                2'd1: total_seq_minus1 <= (total_alive_init) - 1; // N - 1
                2'd2: total_seq_minus1 <= (total_alive_init * total_alive_init) - 1; // N^2 -1
                default: total_seq_minus1 <= (total_alive_init * total_alive_init * total_alive_init) - 1; // N^3 -1
              endcase
            end
          end
        end

        S_ENUM: begin
          // Initialize healths for this sequence based on latched inputs
          my1_h  <= (l_num_my_minions > 0) ? {1'b0,l_my_health_1} : 3'd0;
          my2_h  <= (l_num_my_minions > 1) ? {1'b0,l_my_health_2} : 3'd0;
          opp1_h <= (l_num_opp_minions > 0) ? {1'b0,l_opp_health_1} : 3'd0;
          opp2_h <= (l_num_opp_minions > 1) ? {1'b0,l_opp_health_2} : 3'd0;
          step_cnt <= 3'd0;

          // Initialize per sequence probability to 1.0 in Q16.16
          per_seq_prob <= ONE_Q16_16;
        end

        S_CHECK: begin
          if (step_cnt < l_d) begin
            // Compute number of alive minions at this step
            total_alive_curr = 3'd0;
            if (my1_h  > 0) total_alive_curr = total_alive_curr + 3'd1;
            if (my2_h  > 0) total_alive_curr = total_alive_curr + 3'd1;
            if (opp1_h > 0) total_alive_curr = total_alive_curr + 3'd1;
            if (opp2_h > 0) total_alive_curr = total_alive_curr + 3'd1;

            if (total_alive_curr == 0) begin
              // No targets: this sequence has zero probability from this step on
              per_seq_prob <= 32'd0;
              step_cnt <= l_d; // force completion
            end else begin
              // Determine target selection from seq_idx and step_cnt
              // For max d=3, use base up to 4 encoded directly from seq_idx bits
              case (l_d)
                2'd1: begin
                  target_sel = seq_idx[1:0];
                end
                2'd2: begin
                  if (step_cnt == 0)
                    target_sel = seq_idx[1:0];
                  else
                    target_sel = seq_idx[3:2];
                end
                default: begin
                  if (step_cnt == 0)
                    target_sel = seq_idx[1:0];
                  else if (step_cnt == 1)
                    target_sel = seq_idx[3:2];
                  else
                    target_sel = seq_idx[5:4];
                end
              endcase

              // Map target_sel to an actual alive minion index deterministically
              // We effectively select target_sel modulo total_alive_curr using ordered list
              // Order: my1, my2, opp1, opp2
              // Compute index in 0..total_alive_curr-1
              reg [1:0] sel_mod;
              reg [2:0] idx;
              sel_mod = target_sel;
              if (sel_mod >= total_alive_curr)
                sel_mod = sel_mod - total_alive_curr;

              idx = 3'd0;
              // Iterate through alive list to find sel_mod-th alive
              // my1
              if (my1_h > 0) begin
                if (sel_mod == 0) idx = 3'd0;
                sel_mod = (sel_mod == 0) ? sel_mod : (sel_mod - 1);
              end
              // my2
              if (my2_h > 0 && sel_mod != 2'h3) begin
                if ((my1_h == 0 && sel_mod == 0) || (my1_h > 0 && sel_mod == 0 && idx != 3'd0)) idx = 3'd1;
                if ((my1_h == 0 && sel_mod == 0) || (my1_h > 0 && sel_mod == 0 && idx != 3'd1)) sel_mod = sel_mod;
                else if (sel_mod != 0 && ((my1_h > 0 && idx == 3'd0) || (my1_h == 0))) sel_mod = sel_mod - 1;
              end
              // For robust and simple, re-derive without tricky dependencies
              // Reset logic using a clearer sequence
              begin
                reg [1:0] s;
                reg [2:0] chosen;
                s = target_sel;

                // wrap
                if (s >= total_alive_curr)
                  s = s - total_alive_curr;

                // Scan through in order
                chosen = 3'd0;
                if (my1_h > 0) begin
                  if (s == 0) chosen = 3'd0;
                  s = (s == 0) ? s : s - 1;
                end
                if (my2_h > 0 && (my1_h == 0 || s != 2'h3)) begin
                  if ((my1_h == 0 && s == 0) || (my1_h > 0 && s == 0 && chosen != 3'd1)) chosen = 3'd1;
                  s = (s == 0) ? s : s - 1;
                end
                if (opp1_h > 0 && (my1_h == 0 || my2_h == 0 || s != 2'h3)) begin
                  if (s == 0) chosen = 3'd2;
                  s = (s == 0) ? s : s - 1;
                end
                if (opp2_h > 0 && (my1_h == 0 || my2_h == 0 || opp1_h == 0 || s != 2'h3)) begin
                  if (s == 0) chosen = 3'd3;
                end
                idx = chosen;
              end

              // Apply damage of 1 unit to chosen minion (damage unit size = 1 per step)
              case (idx)
                3'd0: if (my1_h > 0) my1_h <= (my1_h > 0) ? (my1_h - 1) : 3'd0;
                3'd1: if (my2_h > 0) my2_h <= (my2_h > 0) ? (my2_h - 1) : 3'd0;
                3'd2: if (opp1_h > 0) opp1_h <= (opp1_h > 0) ? (opp1_h - 1) : 3'd0;
                3'd3: if (opp2_h > 0) opp2_h <= (opp2_h > 0) ? (opp2_h - 1) : 3'd0;
                default: ;
              endcase

              // Update per-sequence probability: multiply by 1 / total_alive_curr
              // Using Q16.16: per_seq_prob *= (ONE_Q16_16 / total_alive_curr)
              case (total_alive_curr)
                3'd1: tmp_prob = ONE_Q16_16;                        // 1.0
                3'd2: tmp_prob = 32'h00008000;                      // 0.5
                3'd3: tmp_prob = 32'h00005555;                      // 1/3 approx
                3'd4: tmp_prob = 32'h00004000;                      // 0.25
                default: tmp_prob = 32'd0;                          // Should not occur
              endcase

              // Multiply (per_seq_prob * tmp_prob) >> 16
              // 32x32 -> 64; use simple truncation
              begin
                reg [63:0] mul_res;
                mul_res = per_seq_prob * tmp_prob;
                per_seq_prob <= mul_res[47:16];
              end

              // Increment step counter
              step_cnt <= step_cnt + 3'd1;
            end
          end
        end

        S_NEXT: begin
          // Check if all opponent minions are dead after this sequence
          if ((l_num_opp_minions == 0) ||
              ((l_num_opp_minions >= 1) && (opp1_h == 0) &&
               ((l_num_opp_minions == 1) || (opp2_h == 0)))) begin
            success_prob <= success_prob + per_seq_prob;
          end

          // Move to next sequence
          if (seq_idx < total_seq_minus1)
            seq_idx <= seq_idx + 6'd1;
        end

        S_FINISH: begin
          // Normalize final probability: success_prob already represents
          // sum over all sequences with inherent per-step 1/N factors,
          // so it's directly the final probability.
          prob <= success_prob;
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

endmodule