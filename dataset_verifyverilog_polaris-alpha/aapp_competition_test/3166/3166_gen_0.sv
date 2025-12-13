module tournament_disqualify(
  input clk,
  input rst_n,
  input start,
  input [15:0] adj_matrix,
  input [3:0] original_S_mask,
  output reg [2:0] result,
  output reg done
);

  // State encoding
  typedef enum logic [2:0] {
    ST_IDLE   = 3'd0,
    ST_INIT   = 3'd1,
    ST_GEN    = 3'd2,
    ST_PIPE1  = 3'd3,
    ST_PIPE2  = 3'd4,
    ST_PIPE3  = 3'd5,
    ST_FINISH = 3'd6
  } state_t;

  state_t state, next_state;

  // Control and search variables
  reg [1:0] k;                 // original disqualified count (0..4, but spec max k=3 considered)
  reg [1:0] best_k_prime;      // best found k'
  reg       found_any;         // flag that some valid k' subset found

  reg [3:0] subset_mask;       // current subset S'
  reg [2:0] subset_size;       // popcount(subset_mask)

  reg [3:0] cand_mask;         // candidate allowed mask = ~original_S_mask

  // Pipeline registers
  // Stage1 -> Stage2
  reg [3:0] s1_subset_mask;
  reg [2:0] s1_subset_size;
  // Stage2 -> Stage3
  reg [3:0] s2_subset_mask;
  reg [2:0] s2_subset_size;
  reg [15:0] s2_reach;         // reachability matrix (4x4) flat

  // Helper function: count bits in 4-bit vector
  function automatic [2:0] popcount4(input [3:0] v);
    popcount4 = v[0] + v[1] + v[2] + v[3];
  endfunction

  // Compute k from original_S_mask (combinational)
  wire [2:0] k_count = popcount4(original_S_mask);

  // Next subset generation limited to candidates and size<k
  function automatic [3:0] next_subset(
    input [3:0] cur,
    input [3:0] allowed
  );
    reg [3:0] t;
    t = cur;
    // standard next-subset over a fixed 4-bit space, respecting allowed mask
    // Iterate upward until we either hit 4'b1111+1 or match allowed constraints
    // Because space is tiny, just increment and mask-check.
    if (t == 4'b0000) begin
      // start from first allowed single bit combination candidate
      t = 4'b0001;
    end else begin
      t = t + 4'b0001;
    end

    // Loop through up to 16 combinations
    repeat (16) begin
      if ((t & ~allowed) == 4'b0000) begin
        next_subset = t;
        return;
      end
      t = t + 4'b0001;
    end
    next_subset = 4'b0000; // indicates no more
  endfunction

  // Synchronous FSM state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= ST_IDLE;
      result        <= 3'b000;
      done          <= 1'b0;
      best_k_prime  <= 2'd3;
      found_any     <= 1'b0;
      subset_mask   <= 4'b0000;
      subset_size   <= 3'd0;
      cand_mask     <= 4'b0000;
      s1_subset_mask<= 4'b0000;
      s1_subset_size<= 3'd0;
      s2_subset_mask<= 4'b0000;
      s2_subset_size<= 3'd0;
      s2_reach      <= 16'b0;
    end else begin
      state <= next_state;

      case (state)
        ST_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // latch initial parameters
            best_k_prime  <= 2'd3;  // max considered
            found_any     <= 1'b0;
            subset_mask   <= 4'b0000;
            subset_size   <= 3'd0;
            cand_mask     <= ~original_S_mask;
            result        <= 3'b000;
          end
        end

        ST_INIT: begin
          // Start with smallest k' = 0 and iterate implicitly via subset sizes
          subset_mask   <= 4'b0000; // no subset yet
          subset_size   <= 3'd0;
        end

        ST_GEN: begin
          // Generate next subset obeying:
          // - disjoint from original_S_mask (enforced via cand_mask)
          // - size < k
          // Use next_subset helper, then filter by size<k
          // If no valid subset, move toward finish
          if (k_count == 0) begin
            // No smaller k' (<0) exists => impossible immediately
            // handled in ST_FINISH
          end else begin
            // get candidate
            subset_mask <= next_subset(subset_mask, cand_mask);
            subset_size <= popcount4(next_subset(subset_mask, cand_mask));
          end
        end

        ST_PIPE1: begin
          // Latch subset into stage1 only if it is valid and size < k
          if (subset_mask != 4'b0000 && subset_size < k_count) begin
            s1_subset_mask <= subset_mask;
            s1_subset_size <= subset_size;
          end else begin
            s1_subset_mask <= 4'b0000;
            s1_subset_size <= 3'd0;
          end
        end

        ST_PIPE2: begin
          // Build reachability matrix for S' complement (players not disqualified)
          // We compute for full 4 nodes but will only use nodes that are NOT
          // in (original_S_mask | S1).
          integer i, j, kidx;
          reg [15:0] reach;
          reg [3:0]  disable_mask;
          disable_mask = original_S_mask | s1_subset_mask;

          // Initialize reach from adj_matrix, but zero rows/cols of disabled nodes
          reach = 16'b0;
          for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
              if (disable_mask[i] || disable_mask[j]) begin
                // disabled nodes have no edges
                reach[i*4 + j] = 1'b0;
              end else begin
                reach[i*4 + j] = adj_matrix[i*4 + j];
              end
            end
          end

          // Floyd-Warshall for reachability on 4 nodes
          for (kidx = 0; kidx < 4; kidx = kidx + 1) begin
            for (i = 0; i < 4; i = i + 1) begin
              for (j = 0; j < 4; j = j + 1) begin
                if (!reach[i*4 + j]) begin
                  if (reach[i*4 + kidx] && reach[kidx*4 + j]) begin
                    reach[i*4 + j] = 1'b1;
                  end
                end
              end
            end
          end

          s2_subset_mask <= s1_subset_mask;
          s2_subset_size <= s1_subset_size;
          s2_reach       <= reach;
        end

        ST_PIPE3: begin
          // Check for cycle in remaining graph
          // cycle if reach[i][i] == 1 for any enabled node i
          integer i2;
          reg has_cycle;
          reg [3:0] disable_mask2;
          has_cycle     = 1'b0;
          disable_mask2 = original_S_mask | s2_subset_mask;
          for (i2 = 0; i2 < 4; i2 = i2 + 1) begin
            if (!disable_mask2[i2]) begin
              if (s2_reach[i2*4 + i2]) begin
                has_cycle = 1'b1;
              end
            end
          end

          if (!has_cycle && s2_subset_mask != 4'b0000 && s2_subset_size < k_count) begin
            // Valid solution; track minimal k'
            if (!found_any || (s2_subset_size[1:0] < best_k_prime)) begin
              best_k_prime <= s2_subset_size[1:0];
            end
            found_any <= 1'b1;
          end
        end

        ST_FINISH: begin
          done <= 1'b1;
          if (!found_any) begin
            // impossible
            result <= {1'b1, 2'b00};
          end else begin
            result <= {1'b0, best_k_prime};
          end
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic (combinational)
  always @(*) begin
    next_state = state;
    case (state)
      ST_IDLE: begin
        if (start) begin
          next_state = ST_INIT;
        end
      end

      ST_INIT: begin
        // If k==0 then impossible (no smaller k'), go directly to finish
        if (k_count == 0) begin
          next_state = ST_FINISH;
        end else begin
          next_state = ST_GEN;
        end
      end

      ST_GEN: begin
        // If no more subsets (subset_mask wrapped to 0) => FINISH
        if (next_subset(subset_mask, cand_mask) == 4'b0000) begin
          next_state = ST_FINISH;
        end else begin
          next_state = ST_PIPE1;
        end
      end

      ST_PIPE1: begin
        next_state = ST_PIPE2;
      end

      ST_PIPE2: begin
        next_state = ST_PIPE3;
      end

      ST_PIPE3: begin
        // After checking this subset, go back to generate next
        next_state = ST_GEN;
      end

      ST_FINISH: begin
        // Wait here until start is deasserted and asserted again
        if (!start) begin
          next_state = ST_IDLE;
        end
      end

      default: begin
        next_state = ST_IDLE;
      end
    endcase
  end

endmodule