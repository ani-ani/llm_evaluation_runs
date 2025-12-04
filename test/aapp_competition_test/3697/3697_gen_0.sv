module election_predictor(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] k,
  input [7:0] m_remaining,
  input [2:0] candidate_id,
  input [7:0] current_votes,
  input [7:0] last_vote_time,
  input load_data,
  output reg [1:0] result,
  output reg done
);

  // Storage for up to 8 candidates
  reg [7:0] votes    [0:7];
  reg [7:0] time_v    [0:7];

  // Sorted indices
  reg [2:0] idx0, idx1, idx2, idx3, idx4, idx5, idx6, idx7;

  // Result bits per candidate (2 bits each)
  reg [1:0] result_vec [0:7];

  // FSM states
  localparam S_IDLE   = 3'd0;
  localparam S_SORT   = 3'd1;
  localparam S_EVAL   = 3'd2;
  localparam S_OUT    = 3'd3;

  reg [2:0] state, next_state;

  // Output index
  reg [2:0] out_idx;

  // Internal wires for sorted compare operations
  // Function: returns 1 if (a_votes, a_time, a_idx) should come before (b_votes, b_time, b_idx)
  function automatic cmp_before;
    input [7:0] a_votes, b_votes;
    input [7:0] a_time,  b_time;
    input [2:0] a_idx,   b_idx;
    begin
      if (a_votes > b_votes)
        cmp_before = 1'b1;
      else if (a_votes < b_votes)
        cmp_before = 1'b0;
      else if (a_time < b_time)
        cmp_before = 1'b1;
      else if (a_time > b_time)
        cmp_before = 1'b0;
      else
        cmp_before = (a_idx < b_idx);
    end
  endfunction

  // Compare-swap task
  task automatic cswap;
    inout [2:0] a_idx;
    inout [2:0] b_idx;
    reg   [2:0] ta, tb;
    begin
      ta = a_idx;
      tb = b_idx;
      if (!cmp_before(votes[ta], votes[tb], time_v[ta], time_v[tb], ta, tb)) begin
        a_idx = tb;
        b_idx = ta;
      end
    end
  endtask

  // Synchronous storage update and FSM state register
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= S_IDLE;
      done    <= 1'b0;
      result  <= 2'b00;
      out_idx <= 3'd0;
      for (i = 0; i < 8; i = i + 1) begin
        votes[i]      <= 8'd0;
        time_v[i]     <= 8'd0;
        result_vec[i] <= 2'd0;
      end
      idx0 <= 3'd0;
      idx1 <= 3'd1;
      idx2 <= 3'd2;
      idx3 <= 3'd3;
      idx4 <= 3'd4;
      idx5 <= 3'd5;
      idx6 <= 3'd6;
      idx7 <= 3'd7;
    end else begin
      // Load candidate data
      if (load_data) begin
        votes[candidate_id]  <= current_votes;
        time_v[candidate_id] <= last_vote_time;
      end

      state <= next_state;

      case (state)
        S_IDLE: begin
          done    <= 1'b0;
          result  <= 2'b00;
          out_idx <= 3'd0;
          // Initialize indices
          idx0 <= 3'd0;
          idx1 <= 3'd1;
          idx2 <= 3'd2;
          idx3 <= 3'd3;
          idx4 <= 3'd4;
          idx5 <= 3'd5;
          idx6 <= 3'd6;
          idx7 <= 3'd7;
          if (start) begin
            // nothing else; next_state will handle
          end
        end

        S_SORT: begin
          // Perform full unrolled 8-input sorting network (descending votes, ascending time)
          // Using compare-swap on indices only (data from votes/time_v arrays)

          // Stage 1
          cswap(idx0, idx1);
          cswap(idx2, idx3);
          cswap(idx4, idx5);
          cswap(idx6, idx7);

          // Stage 2
          cswap(idx0, idx2);
          cswap(idx1, idx3);
          cswap(idx4, idx6);
          cswap(idx5, idx7);

          // Stage 3
          cswap(idx1, idx2);
          cswap(idx5, idx6);

          // Stage 4
          cswap(idx0, idx4);
          cswap(idx1, idx5);
          cswap(idx2, idx6);
          cswap(idx3, idx7);

          // Stage 5
          cswap(idx2, idx4);
          cswap(idx3, idx5);

          // Stage 6
          cswap(idx1, idx2);
          cswap(idx3, idx4);
          cswap(idx5, idx6);
        end

        S_EVAL: begin
          // Compute result_vec based on sorted order and remaining votes
          // Masks for active candidates based on n
          reg [7:0] active_mask;
          reg [7:0] sorted_ids [0:7];
          reg [7:0] score [0:7];
          reg [7:0] best_others [0:7];
          reg [7:0] diff [0:7];
          reg [9:0] max_gain;
          reg [9:0] share;
          integer j;

          // Active candidates: id < n
          active_mask = 8'h00;
          for (j = 0; j < 8; j = j + 1) begin
            if (j < n)
              active_mask[j] = 1'b1;
            else
              active_mask[j] = 1'b0;
          end

          // Map sorted indices into array for easier use
          sorted_ids[0] = idx0;
          sorted_ids[1] = idx1;
          sorted_ids[2] = idx2;
          sorted_ids[3] = idx3;
          sorted_ids[4] = idx4;
          sorted_ids[5] = idx5;
          sorted_ids[6] = idx6;
          sorted_ids[7] = idx7;

          // Precompute score = votes (8-bit, fits)
          for (j = 0; j < 8; j = j + 1) begin
            score[j] = votes[j];
          end

          // For each candidate, find best competing score among others
          for (j = 0; j < 8; j = j + 1) begin
            integer p;
            reg [7:0] cid;
            reg [7:0] best;
            cid  = j[2:0];
            best = 8'd0;

            if (!active_mask[cid]) begin
              best_others[cid] = 8'd0;
            end else begin
              for (p = 0; p < 8; p = p + 1) begin
                reg [7:0] oid;
                oid = sorted_ids[p];
                if (active_mask[oid] && (oid != cid)) begin
                  if (score[oid] > best)
                    best = score[oid];
                end
              end
              best_others[cid] = best;
            end
          end

          // Compute result_vec for each candidate
          // Simple model:
          // - Let share = m_remaining / max(n,1)
          // - Let max_gain = share (integer division)
          // - diff = best_others - score
          // If not active: result=3
          // Else if candidate index in top-k of sorted active -> possible seat (2) by default
          // Additional checks (guaranteed / impossible) based on diff and max_gain:
          //   Guaranteed (1): diff >= 0 but diff > max_gain for all rivals below k? Simplified:
          //     if score[c] + max_gain < best_others[c] -> no chance (3)
          //     else if score[c] > best_others[c] + max_gain -> guaranteed (1)
          //   Otherwise: possible (2)

          share = (n != 0) ? (m_remaining / n) : 10'd0;
          max_gain = share;

          // Initialize all to 3
          for (j = 0; j < 8; j = j + 1) begin
            result_vec[j] <= 2'd3;
          end

          for (j = 0; j < 8; j = j + 1) begin
            reg [2:0] cid3;
            reg [7:0] cid;
            reg [7:0] bo;
            cid3 = j[2:0];
            cid  = j[7:0];
            if (!active_mask[cid3]) begin
              result_vec[cid3] <= 2'd3; // inactive
            end else begin
              bo = best_others[cid3];
              if (score[cid3] + max_gain < bo) begin
                // cannot catch top
                result_vec[cid3] <= 2'd3;
              end else if (score[cid3] > bo + max_gain) begin
                // safely ahead
                result_vec[cid3] <= 2'd1;
              end else begin
                // possible
                result_vec[cid3] <= 2'd2;
              end
            end
          end
        end

        S_OUT: begin
          // Sequentially output result_vec for each candidate id 0..n-1
          done <= 1'b1;
          if (out_idx < n) begin
            result <= result_vec[out_idx];
            out_idx <= out_idx + 3'd1;
          end else begin
            result <= 2'b00;
          end
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_SORT;
      end
      S_SORT: begin
        // Sorting done in a single cycle combinationally
        next_state = S_EVAL;
      end
      S_EVAL: begin
        // Evaluate in one cycle
        next_state = S_OUT;
      end
      S_OUT: begin
        // Stay in OUT until possibly reset or new start (design choice: stay)
        next_state = S_OUT;
      end
      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule