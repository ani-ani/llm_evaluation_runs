module translator_pairing(
  input clk,
  input rst_n,
  input start,
  input [2:0] M,
  input [2:0] N,
  input [2:0] lang1 [0:7],
  input [2:0] lang2 [0:7],
  output reg [2:0] pair1,
  output reg [2:0] pair2,
  output reg done,
  output reg impossible
);

  // State encoding
  localparam IDLE         = 3'd0;
  localparam CHECK_INIT   = 3'd1;
  localparam CHECK_PAIRS  = 3'd2;
  localparam OUTPUT_PAIR  = 3'd3;
  localparam IMPOSS_STATE = 3'd4;
  localparam DONE_STATE   = 3'd5;

  reg [2:0] state, next_state;

  // Internal storage
  reg [2:0] M_reg;
  reg [2:0] lang1_reg [0:7];
  reg [2:0] lang2_reg [0:7];

  reg used [0:7];

  reg [2:0] i_idx;        // current left translator index for pairing search
  reg [2:0] j_idx;        // current right translator index for pairing search

  reg [2:0] pairs_a [0:3];
  reg [2:0] pairs_b [0:3];
  reg [2:0] pair_count;   // number of pairs found (0..4)

  reg found_match;        // combinational flag for match in current check

  // language match function
  function automatic match_lang;
    input [2:0] a1;
    input [2:0] a2;
    input [2:0] b1;
    input [2:0] b2;
    begin
      match_lang = (a1 == b1) || (a1 == b2) || (a2 == b1) || (a2 == b2);
    end
  endfunction

  // Asynchronous reset, sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      pair1       <= 3'd0;
      pair2       <= 3'd0;
      done        <= 1'b0;
      impossible  <= 1'b0;
      M_reg       <= 3'd0;
      i_idx       <= 3'd0;
      j_idx       <= 3'd0;
      pair_count  <= 3'd0;
      used[0]     <= 1'b0;
      used[1]     <= 1'b0;
      used[2]     <= 1'b0;
      used[3]     <= 1'b0;
      used[4]     <= 1'b0;
      used[5]     <= 1'b0;
      used[6]     <= 1'b0;
      used[7]     <= 1'b0;
    end else begin
      state <= next_state;

      // default single-cycle pulse outputs low unless set in state actions
      done       <= 1'b0;
      impossible <= 1'b0;

      case (state)
        IDLE: begin
          // Wait for start, capture inputs when start asserted
          if (start) begin
            M_reg <= M;
            // Latch language arrays
            lang1_reg[0] <= lang1[0];
            lang1_reg[1] <= lang1[1];
            lang1_reg[2] <= lang1[2];
            lang1_reg[3] <= lang1[3];
            lang1_reg[4] <= lang1[4];
            lang1_reg[5] <= lang1[5];
            lang1_reg[6] <= lang1[6];
            lang1_reg[7] <= lang1[7];

            lang2_reg[0] <= lang2[0];
            lang2_reg[1] <= lang2[1];
            lang2_reg[2] <= lang2[2];
            lang2_reg[3] <= lang2[3];
            lang2_reg[4] <= lang2[4];
            lang2_reg[5] <= lang2[5];
            lang2_reg[6] <= lang2[6];
            lang2_reg[7] <= lang2[7];

            // Clear used flags
            used[0] <= 1'b0;
            used[1] <= 1'b0;
            used[2] <= 1'b0;
            used[3] <= 1'b0;
            used[4] <= 1'b0;
            used[5] <= 1'b0;
            used[6] <= 1'b0;
            used[7] <= 1'b0;

            pair_count <= 3'd0;
            i_idx      <= 3'd0;
            j_idx      <= 3'd1;
          end
        end

        CHECK_INIT: begin
          // No sequential actions here beyond what is done on transition
        end

        CHECK_PAIRS: begin
          if (!found_match) begin
            // advance search indices when no match on this step
            if (j_idx < M_reg) begin
              j_idx <= j_idx + 3'd1;
            end else begin
              // finished scanning for this i without match, move to next i
              // find next unused i
              if (i_idx + 3'd1 < M_reg) begin
                i_idx <= i_idx + 3'd1;
                j_idx <= (i_idx + 3'd1) + 3'd1; // will be corrected by next_state logic
              end
            end
          end else begin
            // found a match: record pair, mark used, and move to next i
            pairs_a[pair_count] <= i_idx;
            pairs_b[pair_count] <= j_idx;
            pair_count          <= pair_count + 3'd1;
            used[i_idx]         <= 1'b1;
            used[j_idx]         <= 1'b1;

            // move i to next unused
            // j will be set in next_state logic
          end
        end

        OUTPUT_PAIR: begin
          // Pulse done while outputting current pair (handled in comb block)
        end

        IMPOSS_STATE: begin
          // Pulse impossible for one cycle
          impossible <= 1'b1;
        end

        DONE_STATE: begin
          // All pairs already output; nothing additional
        end

        default: begin
        end
      endcase
    end
  end

  // Combinational next-state and control logic
  integer k;
  reg [2:0] next_i;
  reg [2:0] next_j;
  reg all_used;
  reg any_unpaired;

  always @* begin
    next_state = state;
    found_match = 1'b0;

    // Defaults for next indices
    next_i = i_idx;
    next_j = j_idx;
    all_used = 1'b1;
    any_unpaired = 1'b0;

    // Evaluate used status for current M_reg
    for (k = 0; k < 8; k = k + 1) begin
      if (k < M_reg) begin
        if (!used[k]) begin
          all_used = 1'b0;
          any_unpaired = 1'b1;
        end
      end
    end

    case (state)
      IDLE: begin
        if (start) begin
          // If odd number of translators, immediately impossible next
          if (M[0] == 1'b1) begin
            next_state = IMPOSS_STATE;
          end else if (M == 3'd0) begin
            // No translators: trivially done (no pairs)
            next_state = DONE_STATE;
          end else begin
            next_state = CHECK_INIT;
          end
        end
      end

      CHECK_INIT: begin
        // Initialize search indices to first unused pair (0,1)
        next_i = 3'd0;
        // ensure i is unused; but just starting so all unused
        next_j = 3'd1;
        // go to CHECK_PAIRS to start search
        next_state = CHECK_PAIRS;
      end

      CHECK_PAIRS: begin
        // If all translators are used and we have M/2 pairs, go to OUTPUT or DONE
        if (all_used) begin
          // We have a complete pairing
          if (pair_count == (M_reg >> 1)) begin
            // Prepare to output first pair
            next_state = OUTPUT_PAIR;
          end else begin
            // Safety fallback: treat as impossible if counts mismatch
            next_state = IMPOSS_STATE;
          end
        end else begin
          // Not all used: continue searching

          // Ensure current i_idx is unused and within range; if used or out of range, move to next.
          if ((i_idx >= M_reg) || used[i_idx]) begin
            // find next unused i
            next_i = 3'd7; // default
            for (k = 0; k < 8; k = k + 1) begin
              if ((k < M_reg) && !used[k]) begin
                next_i = k[2:0];
                break;
              end
            end
            // If none found, check if all used
            if (next_i >= M_reg) begin
              // no unused found but all_used should've been true; treat as impossible
              next_state = IMPOSS_STATE;
            end else begin
              // set j just after new i
              next_j = next_i + 3'd1;
            end
          end else begin
            // i_idx is valid and unused; check if any possible j exists
            if (j_idx >= M_reg) begin
              // we exhausted j for this i without match -> impossible (this i cannot be paired)
              next_state = IMPOSS_STATE;
            end else if (!used[j_idx] && match_lang(lang1_reg[i_idx], lang2_reg[i_idx], lang1_reg[j_idx], lang2_reg[j_idx])) begin
              // Found a valid pair (i_idx, j_idx)
              found_match = 1'b1;
              // After recording, move to next unused i
              // compute next_i as next unused index
              next_i = 3'd7; // default
              for (k = 0; k < 8; k = k + 1) begin
                if ((k < M_reg) && !used[k] && (k != i_idx) && (k != j_idx)) begin
                  next_i = k[2:0];
                  break;
                end
              end
              if (next_i >= M_reg) begin
                // no more i: we might be done; CHECK_PAIRS state will see all_used next cycle
                next_j = 3'd0;
              end else begin
                next_j = next_i + 3'd1;
              end
              next_state = CHECK_PAIRS;
            end else begin
              // No match yet; advance j within sequential block next cycle
              next_state = CHECK_PAIRS;
            end
          end
        end
      end

      OUTPUT_PAIR: begin
        // Output pairs sequentially with done pulse
        // Use pair_count as remaining count; reuse it implicitly using index (pair_count-1) or similar
        // We will drive outputs directly here based on an internal counter; implement separate index.
        // Simple approach: use pair_count as total, use i_idx as output index.
      end

      IMPOSS_STATE: begin
        // After pulsing impossible, go back to IDLE
        next_state = IDLE;
      end

      DONE_STATE: begin
        // Completed successfully; return to IDLE
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Output sequencing for pairs
  // Use a separate counter 'out_idx' to iterate through stored pairs
  reg [2:0] out_idx;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      out_idx <= 3'd0;
    end else begin
      case (state)
        CHECK_PAIRS: begin
          if (next_state == OUTPUT_PAIR) begin
            out_idx <= 3'd0;
          end
        end
        OUTPUT_PAIR: begin
          if (out_idx < pair_count) begin
            pair1 <= pairs_a[out_idx];
            pair2 <= pairs_b[out_idx];
            done  <= 1'b1; // pulse done with each pair
            out_idx <= out_idx + 3'd1;
          end
        end
        default: begin
          out_idx <= (next_state == OUTPUT_PAIR) ? 3'd0 : out_idx;
        end
      endcase
    end
  end

  // Transition out of OUTPUT_PAIR when all pairs have been emitted
  always @* begin
    if (state == OUTPUT_PAIR) begin
      if (out_idx >= pair_count) begin
        // after last pair pulse, move to DONE_STATE next
        if (next_state == OUTPUT_PAIR) begin
          // override to DONE_STATE
        end
      end
    end
  end

  // Final next_state adjustment for OUTPUT_PAIR based on out_idx
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // already handled
    end else begin
      if (state == OUTPUT_PAIR) begin
        if (out_idx >= pair_count) begin
          // move to DONE_STATE
          state <= DONE_STATE;
        end
      end
    end
  end

endmodule