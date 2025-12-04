module ncpc_partition (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] a,
  input [2:0] b,
  input [5:0] year,
  input valid_pair,
  output reg [5:0] Y,
  output reg impossible,
  output reg done
);

  // Maximum number of participants is 6 (n is 4..6 as per problem)
  localparam MAX_P = 6;
  localparam NUM_PAIRS = 15; // upper-triangular for 6 nodes: (i<j) -> 6*5/2 = 15

  // Adjacency matrix storing years for pairs (0 when not set)
  // mat[i][j] where i<j; index mapping below
  reg [5:0] mat [0:5][0:5];

  // Storage FSM states
  localparam ST_IDLE  = 3'b000;
  localparam ST_STORE = 3'b001;
  localparam ST_COMP  = 3'b010;

  reg [2:0] state, state_next;
  reg [5:0] Y_candidate;
  reg Y_candidate_next;
  reg impossible_next;
  reg done_next;

  // Current comp of Y being tested
  reg [5:0] comp_idx, comp_idx_next;

  // Union-Find parent for up to 6 participants (1..n)
  reg [2:0] parent [1:MAX_P];
  reg [2:0] rank   [1:MAX_P];
  reg [2:0] size   [1:MAX_P];

  // When finding components for a Y:
  // - comp_class[c] = 0 => not set yet
  // - comp_class[c] = 1 => AA (both endpoints in group A because year <= Y)
  // - comp_class[c] = 2 => AB (endpoints in different groups because year > Y)
  // - comp_class[c] = 3 => BB (both endpoints in group B because year > Y)
  reg [1:0] comp_class [0:5]; // up to 5 components (0..n-1)
  reg [2:0] comp_count, comp_count_next;

  // Active (has at least one pair) participant bitmask for current Y
  reg [5:0] active_bits, active_bits_next;
  // Inactive participant bitmask (can go anywhere, used to fill leftovers)
  reg [5:0] inactive_bits, inactive_bits_next;

  // Component sizes and bitmasks (for up to 5 components, but we build for up to n-1)
  reg [2:0] comp_sizes [0:5];       // size (1..n)
  reg [5:0] comp_masks [0:5];       // bitmask of participants in component

  // Smallest valid Y found so far during the scan
  reg [5:0] Y_best, Y_best_next;
  reg found_any, found_any_next;

  // Helper: linear index for upper-triangular storage mat[i][j] (i<j)
  // idx = (i * MAX_P) - (i * (i+1) / 2) + (j - i - 1)
  function [3:0] pair_index(input [2:0] i, input [2:0] j);
    reg [3:0] iu, ju;
    iu = i[3:0];
    ju = j[3:0];
    // i<j guaranteed by caller; this formula works for 0-based indices
    pair_index = (iu * MAX_P) - ((iu * (iu + 1)) >> 1) + (ju - iu - 1);
  endfunction

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= ST_IDLE;
      Y <= 6'd0;
      impossible <= 1'b0;
      done <= 1'b0;
      Y_candidate <= 6'd0;
      comp_idx <= 6'd0;
      comp_count <= 3'd0;
      active_bits <= 6'd0;
      inactive_bits <= 6'd0;
      Y_best <= 6'd0;
      found_any <= 1'b0;
      // Clear adjacency matrix and union-find (parents = self, rank=0)
      for (int i=0; i<MAX_P; i++) begin
        for (int j=0; j<MAX_P; j++) begin
          mat[i][j] <= 6'd0;
        end
      end
      for (int k=1; k<=MAX_P; k++) begin
        parent[k] <= k[2:0];
        rank[k]   <= 2'b00;
        size[k]   <= 3'd1;
        comp_sizes[k-1] <= 3'd1;
        comp_masks[k-1] <= 6'd0;
        comp_class[k-1] <= 2'b00;
      end
    end else begin
      state <= state_next;
      Y <= Y_next;
      impossible <= impossible_next;
      done <= done_next;
      Y_candidate <= Y_candidate_next;
      comp_idx <= comp_idx_next;
      comp_count <= comp_count_next;
      active_bits <= active_bits_next;
      inactive_bits <= inactive_bits_next;
      Y_best <= Y_best_next;
      found_any <= found_any_next;
    end
  end

  // Next-state and output logic (combinational)
  always @* begin
    // defaults
    state_next = state;
    Y_next = Y;
    impossible_next = impossible;
    done_next = 1'b0;
    Y_candidate_next = Y_candidate;
    comp_idx_next = comp_idx;
    comp_count_next = comp_count;
    active_bits_next = active_bits;
    inactive_bits_next = inactive_bits;
    Y_best_next = Y_best;
    found_any_next = found_any;

    // Clear union-find parents each time we start a new Y (fresh for each candidate)
    for (int k=1; k<=MAX_P; k++) begin
      parent[k] = k[2:0];
      rank[k]   = 2'b00;
      size[k]   = 3'd1;
    end

    case (state)
      ST_IDLE: begin
        if (start) begin
          // Begin storing pairs
          state_next = ST_STORE;
          done_next = 1'b0;
          impossible_next = 1'b0;
        end
      end

      ST_STORE: begin
        // Accept new pairs while valid_pair is high
        if (valid_pair) begin
          // Sanity: ensure 0-based indices in [0..5] and i<j
          if (a < b) begin
            mat[a][b] <= year; // store year for pair (a,b)
          end else if (b < a) begin
            mat[b][a] <= year; // swap to keep i<j
          end
        end
        // When start goes low, storage is assumed complete
        if (!start) begin
          // Prepare to start computation
          state_next = ST_COMP;
          done_next = 1'b0;
          impossible_next = 1'b0;
          Y_candidate_next = 6'd0;   // 1948
          comp_idx_next = 6'd0;
          Y_best_next = 6'd0;
          found_any_next = 1'b0;
          // Initialize union-find for current Y (parents already cleared above)
        end
      end

      ST_COMP: begin
        if (start) begin
          // Allow restarting: re-enter STORE to accept new pairs
          state_next = ST_STORE;
          done_next = 1'b0;
          continue;
        end

        // One year per cycle; step through 0..60 (1948..2008)
        // Check feasibility for current Y_candidate
        // Build components for this Y
        // 1) Initialize parents to self (already done above in the comb block)
        // 2) Iterate all pairs (i<j) and union endpoints according to year relation
        // 3) After unions, gather component sizes and bitmasks
        // 4) Compute active bitmask (participants with at least one pair)
        // 5) Try to pack components into two bins of capacity C = floor(2n/3)
        // 6) If feasible, record Y and finish; else increment Y_candidate and repeat

        // Build components for this Y:
        // Clear comp structures
        comp_count_next = 3'd0;
        for (int c=0; c<6; c++) begin
          comp_sizes[c] = 3'd0;
          comp_masks[c] = 6'd0;
          comp_class[c] = 2'b00;
        end

        // Union endpoints within each group for this Y
        for (int i=0; i<MAX_P; i++) begin
          for (int j=i+1; j<MAX_P; j++) begin
            if (mat[i][j] != 6'd0) begin
              // Endpoint indices for union-find (1-based)
              if (mat[i][j] <= Y_candidate) begin
                // Union in AA group
                // union(i+1, j+1)
                // Find roots
                reg [2:0] ri, rj;
                ri = i + 1; rj = j + 1;
                // find with path compression inline
                while (ri != parent[ri]) ri = parent[ri];
                while (rj != parent[rj]) rj = parent[rj];
                if (ri != rj) begin
                  // union by rank
                  if (rank[ri] < rank[rj]) begin
                    parent[ri] = rj;
                    if (rank[ri] == rank[rj]) rank[rj]++;
                  end else begin
                    parent[rj] = ri;
                    if (rank[ri] == rank[rj]) rank[ri]++;
                  end
                end
              end else begin
                // Union in BB group
                reg [2:0] ri, rj;
                ri = i + 1; rj = j + 1;
                while (ri != parent[ri]) ri = parent[ri];
                while (rj != parent[rj]) rj = parent[rj];
                if (ri != rj) begin
                  if (rank[ri] < rank[rj]) begin
                    parent[ri] = rj;
                    if (rank[ri] == rank[rj]) rank[rj]++;
                  end else begin
                    parent[rj] = ri;
                    if (rank[ri] == rank[rj]) rank[ri]++;
                  end
                end
              end
            end
          end
        end

        // Build per-participant component index and sizes
        // We will create compact component indices 0..comp_count-1
        // active_bits: participants that appear in at least one pair
        active_bits_next = 6'd0;
        for (int i=0; i<MAX_P; i++) begin
          if (i < n) begin
            // Count active by checking any mat[i][j] or mat[j][i] non-zero
            reg has_pair;
            has_pair = 1'b0;
            for (int j=0; j<MAX_P; j++) begin
              if (i != j) begin
                if ((i < j) && (mat[i][j] != 6'd0)) has_pair = 1'b1;
                if (i > j) begin
                  // mat is stored only for i<j; read the symmetric entry
                  if (mat[j][i] != 6'd0) has_pair = 1'b1;
                end
              end
            end
            if (has_pair) begin
              active_bits_next[i] = 1'b1;
            end
          end
        end
        inactive_bits_next = ((1 << n) - 1) & ~active_bits_next;

        // Compress roots and build comp_sizes and comp_masks
        // Use an associative-like mapping via a small loop: check if root already used
        reg [5:0] seen_root_mask;
        seen_root_mask = 6'd0;
        comp_count_next = 3'd0;
        for (int i=0; i<MAX_P; i++) begin
          if (i < n) begin
            // Find root
            reg [2:0] ri;
            ri = i + 1;
            while (ri != parent[ri]) ri = parent[ri];
            // Map root to compact index
            reg [2:0] cmap;
            reg found;
            cmap = 3'd0; found = 1'b0;
            for (int c=0; c<6; c++) begin
              if (comp_masks[c][ri-1]) begin
                cmap = c[2:0];
                found = 1'b1;
              end
            end
            if (!found) begin
              // assign new component id
              cmap = comp_count_next;
              comp_count_next = comp_count_next + 3'd1;
            end
            // Add i to this component mask
            comp_masks[cmap][i] = 1'b1;
            comp_sizes[cmap] = comp_sizes[cmap] + 3'd1;
          end
        end

        // Compute capacity C = floor(2n/3)
        reg [2:0] C;
        C = (2 * n) / 3;

        // Check feasibility for this Y:
        // 1) If any component size > C, impossible for this Y (cannot split such a component)
        // 2) Otherwise, try to assign each component to bin A or bin B s.t.
        //    sum sizes in each bin <= C, and active_bits fits exactly
        reg feasible;
        feasible = 1'b1;
        for (int c=0; c<6; c++) begin
          if (comp_sizes[c] > C) feasible = 1'b0;
        end

        // Infeasible if active_bits alone already exceed 2*C (since inactive can be distributed)
        if (feasible) begin
          reg [2:0] cnt_active;
          cnt_active = 3'd0;
          for (int i=0; i<MAX_P; i++) begin
            if (active_bits_next[i]) cnt_active = cnt_active + 3'd1;
          end
          if (cnt_active > (2 * C)) feasible = 1'b0;
        end

        // Exhaustive search of component bin assignment if still feasible
        if (feasible) begin
          reg pack_possible;
          pack_possible = 1'b0;
          // Only need to try assignments that cover active_bits exactly;
          // Iterate over bitmasks for bin A (bin B is complement) limited to up to 2^(comp_count)
          reg [5:0] maskA;
          for (int m=0; m < (1 << comp_count_next); m++) begin
            maskA = 6'd0;
            for (int c=0; c<6; c++) begin
              if (m[c]) maskA = maskA | comp_masks[c];
            end
            // maskA must include all active bits (inactive can be in either bin)
            if ((maskA & active_bits_next) == active_bits_next) begin
              reg [2:0] sumA, sumB;
              sumA = 3'd0; sumB = 3'd0;
              for (int c=0; c<6; c++) begin
                if (m[c]) sumA = sumA + comp_sizes[c];
                else      sumB = sumB + comp_sizes[c];
              end
              if ((sumA <= C) && (sumB <= C)) begin
                pack_possible = 1'b1;
                // break
              end
            end
          end
          feasible = pack_possible;
        end

        if (feasible) begin
          Y_next = Y_candidate;
          impossible_next = 1'b0;
          done_next = 1'b1;
          state_next = ST_IDLE; // go back to idle after completion
        end else begin
          // Not feasible for this Y; try next Y
          if (Y_candidate < 6'd60) begin
            Y_candidate_next = Y_candidate + 6'd1;
            // Note: parents will be re-cleared at top of next cycle (combinational block)
          end else begin
            // Exhausted all years
            Y_next = 6'd0; // value doesn't matter when impossible=1
            impossible_next = 1'b1;
            done_next = 1'b1;
            state_next = ST_IDLE;
          end
        end
      end

      default: begin
        state_next = ST_IDLE;
      end
    endcase
  end

endmodule
