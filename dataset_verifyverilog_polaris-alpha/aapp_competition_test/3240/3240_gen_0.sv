module vote_optimizer(
  input clk,
  input rst_n,
  input start,
  input [3:0] v,
  input [15:0] p_i [0:6],
  input [15:0] b_i [0:6],
  output reg [15:0] b_v,
  output reg done
);

  // Internal parameters
  localparam IDLE      = 3'd0;
  localparam INIT      = 3'd1;
  localparam OUTER     = 3'd2;
  localparam INNER_INIT= 3'd3;
  localparam INNER     = 3'd4;
  localparam UPDATE    = 3'd5;
  localparam FINISH    = 3'd6;

  // Internal registers
  reg [2:0]  state, next_state;

  // Candidate ballot b_v candidate
  reg [15:0] cand_b_v;

  // Track max expected value and associated best ballot
  // Use wider accumulator: Q16.16 style to avoid overflow
  reg [47:0] max_exp;
  reg [15:0] best_b_v;

  // Combination index (over other voters)
  reg [6:0] comb_idx;          // up to 2^7 - 1
  reg [6:0] comb_limit;        // 2^(v-1)

  // Loop index for voters
  reg [2:0] voter_idx;

  // Probability and ballots accumulation
  reg [31:0] prob_acc;         // Q16.16
  reg [15:0] total_ballot;

  // Working registers for inner loops
  reg        include_voter;
  reg [15:0] temp_ballot;
  reg [31:0] temp_prob;

  // Expected value accumulator for current candidate
  reg [47:0] exp_acc;

  // Popcount result for Yraglac wins (0..16)
  reg [4:0] yraglac_wins;

  // Combinational wires for computing comb_limit = 2^(v-1)
  wire [6:0] one_hot_limit = (v > 0) ? (7'd1 << (v - 1)) : 7'd0;

  // Popcount function for 16-bit input
  function automatic [4:0] popcount16(input [15:0] x);
    integer i;
    reg [4:0] cnt;
    begin
      cnt = 5'd0;
      for (i = 0; i < 16; i = i + 1) begin
        cnt = cnt + x[i];
      end
      popcount16 = cnt;
    end
  endfunction

  // Combinational FSM next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = INIT;
      end
      INIT: begin
        next_state = OUTER;
      end
      OUTER: begin
        next_state = INNER_INIT;
      end
      INNER_INIT: begin
        next_state = INNER;
      end
      INNER: begin
        if (comb_idx + 1 >= comb_limit)
          next_state = UPDATE;
        else
          next_state = INNER; // stay until all combinations processed
      end
      UPDATE: begin
        if (cand_b_v == 16'hFFFF)
          next_state = FINISH;
        else
          next_state = OUTER;
      end
      FINISH: begin
        if (!start)
          next_state = IDLE;
        else
          next_state = FINISH;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      done        <= 1'b0;
      cand_b_v    <= 16'd0;
      best_b_v    <= 16'd0;
      max_exp     <= 48'd0;
      comb_idx    <= 7'd0;
      comb_limit  <= 7'd0;
      voter_idx   <= 3'd0;
      prob_acc    <= 32'd0;
      total_ballot<= 16'd0;
      exp_acc     <= 48'd0;
      yraglac_wins<= 5'd0;
      b_v         <= 16'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done        <= 1'b0;
          if (start) begin
            cand_b_v   <= 16'd0;
            best_b_v   <= 16'd0;
            max_exp    <= 48'd0;
            exp_acc    <= 48'd0;
            comb_idx   <= 7'd0;
            comb_limit <= one_hot_limit;
          end
        end

        INIT: begin
          // Initialize for first candidate
          exp_acc     <= 48'd0;
          comb_idx    <= 7'd0;
          comb_limit  <= one_hot_limit;
        end

        OUTER: begin
          // Start evaluating a new candidate cand_b_v
          exp_acc     <= 48'd0;
          comb_idx    <= 7'd0;
        end

        INNER_INIT: begin
          // Initialize per-combination accumulators
          prob_acc     <= 32'd1 << 16; // probability = 1.0 in Q16.16
          total_ballot <= cand_b_v;
          voter_idx    <= 3'd0;
        end

        INNER: begin
          // For each combination index, sequentially process all voters
          if (voter_idx < (v - 1)) begin
            include_voter = comb_idx[voter_idx];

            // Compute probability contribution for this voter
            // p_i: Q8.8, convert to Q16.16 by <<8 when multiplying
            if (include_voter) begin
              // prob_acc *= p_i (Q8.8) => (Q16.16 * Q8.8) >> 8 => Q16.16
              temp_prob = (prob_acc * {8'd0, p_i[voter_idx]}) >> 8;
              prob_acc  <= temp_prob;

              // Add ballot if voter participates
              temp_ballot   = total_ballot + b_i[voter_idx];
              total_ballot  <= temp_ballot;
            end else begin
              // prob_acc *= (1 - p_i)
              // (1 - p_i) in Q8.8: (1.0 = 256) => (256 - p_i)
              temp_prob = (prob_acc * {8'd0, (16'd256 - p_i[voter_idx])}) >> 8;
              prob_acc  <= temp_prob;
              total_ballot <= total_ballot;
            end

            voter_idx <= voter_idx + 3'd1;
          end else begin
            // All relevant voters processed for this combination
            // Compute Yraglac wins: popcount of lower 16 bits
            yraglac_wins <= popcount16(total_ballot);

            // Accumulate expected value: exp_acc += prob_acc * wins
            // prob_acc: Q16.16, wins: integer -> result: Q16.16
            exp_acc <= exp_acc + (prob_acc * yraglac_wins);

            // Move to next combination
            comb_idx <= comb_idx + 7'd1;

            // Re-init for next combination if not done
            if (comb_idx + 1 < comb_limit) begin
              prob_acc     <= 32'd1 << 16;
              total_ballot <= cand_b_v;
              voter_idx    <= 3'd0;
            end
          end
        end

        UPDATE: begin
          // Compare accumulated expected value for this candidate
          if (exp_acc > max_exp) begin
            max_exp   <= exp_acc;
            best_b_v  <= cand_b_v;
          end

          // Prepare next candidate or finish
          if (cand_b_v != 16'hFFFF) begin
            cand_b_v   <= cand_b_v + 16'd1;
            exp_acc    <= 48'd0;
            comb_idx   <= 7'd0;
          end
        end

        FINISH: begin
          // Latch result and assert done
          b_v   <= best_b_v;
          done  <= 1'b1;
        end

        default: ;
      endcase
    end
  end

endmodule