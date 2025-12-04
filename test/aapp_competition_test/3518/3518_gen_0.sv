module min_co2_matcher(
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0] n,
  input  [2:0] m,
  input  [2:0] p [0:27],
  input  [2:0] q [0:27],
  input  [13:0] c [0:27],
  output reg [15:0] min_co2,
  output reg impossible,
  output reg done
);

  // ---------------------------------------------------------------------------
  // Parameters
  // ---------------------------------------------------------------------------
  localparam MAX_N = 8;
  localparam MAX_M = 28;

  // State encoding
  localparam S_IDLE       = 4'd0;
  localparam S_INIT       = 4'd1;
  localparam S_BUILD_LOAD = 4'd2;
  localparam S_BUILD_APPLY= 4'd3;
  localparam S_CHECK_INIT = 4'd4;
  localparam S_CHECK_RUN  = 4'd5;
  localparam S_MATCH_INIT = 4'd6;
  localparam S_MATCH_ENUM = 4'd7;
  localparam S_MATCH_EVAL = 4'd8;
  localparam S_DONE       = 4'd9;

  // ---------------------------------------------------------------------------
  // Internal registers
  // ---------------------------------------------------------------------------

  reg [3:0] state, next_state;

  // Adjacency matrix: adj_cost[i][j], 14-bit; use 16383 as INF
  reg [13:0] adj_cost [0:MAX_N-1][0:MAX_N-1];

  // Working copies / counters
  reg [5:0] edge_idx;       // up to 27
  reg [2:0] bi, bj;         // indices for matrix clear & checks

  // For applying one edge (p[edge_idx], q[edge_idx], c[edge_idx])
  reg [2:0] e_p, e_q;
  reg [13:0] e_c;

  // N and M latched
  reg [2:0] n_reg;
  reg [2:0] m_reg;

  // Clique / connectivity tracking
  reg [7:0] comp_id;        // component id per node (3 bits per node packed not needed; use 3-bit array)
  reg [2:0] comp_of [0:MAX_N-1];
  reg [2:0] comp_deg [0:MAX_N-1]; // reused: count size of each component
  reg       clique_fail;

  // Matching search
  reg [2:0] match [0:MAX_N-1];       // partner index per node (for enumeration)
  reg [7:0] used_mask;               // which nodes used in current partial matching
  reg [2:0] stack_idx;               // depth (0..n_reg)
  reg [2:0] cur_i [0:MAX_N-1];       // node index selected at each depth
  reg [2:0] cur_j [0:MAX_N-1];       // partner chosen for cur_i at each depth
  reg       backtrack;

  reg [15:0] cur_sum;
  reg [15:0] best_sum;
  reg       have_solution;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  localparam [13:0] INF14 = 14'd16383;

  // ---------------------------------------------------------------------------
  // Sequential state and registers
  // ---------------------------------------------------------------------------
  integer i,j;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= S_IDLE;
      min_co2       <= 16'd0;
      impossible    <= 1'b0;
      done          <= 1'b0;
      n_reg         <= 3'd0;
      m_reg         <= 3'd0;
      edge_idx      <= 6'd0;
      bi            <= 3'd0;
      bj            <= 3'd0;
      clique_fail   <= 1'b0;
      have_solution <= 1'b0;
      best_sum      <= 16'hFFFF;
      used_mask     <= 8'd0;
      stack_idx     <= 3'd0;
      cur_sum       <= 16'd0;
      backtrack     <= 1'b0;
      // clear adjacency
      for (i=0;i<MAX_N;i=i+1) begin
        for (j=0;j<MAX_N;j=j+1) begin
          adj_cost[i][j] <= INF14;
        end
      end
    end else begin
      state <= next_state;

      case (state)
        // -------------------------------------------------------------------
        S_IDLE: begin
          done       <= 1'b0;
          impossible <= 1'b0;
          if (start) begin
            // latch n and m
            n_reg    <= n;
            m_reg    <= m;
            // init indices
            bi       <= 3'd0;
            bj       <= 3'd0;
            edge_idx <= 6'd0;
            clique_fail   <= 1'b0;
            have_solution <= 1'b0;
            best_sum      <= 16'hFFFF;
            used_mask     <= 8'd0;
            stack_idx     <= 3'd0;
            cur_sum       <= 16'd0;
            // no adjacency clear here; will be in S_INIT
          end
        end

        // -------------------------------------------------------------------
        // Clear adjacency matrix to INF14
        S_INIT: begin
          adj_cost[bi][bj] <= (bi==bj) ? INF14 : INF14;
          if (bj == MAX_N-1) begin
            bj <= 3'd0;
            if (bi == MAX_N-1) begin
              bi <= 3'd0;
            end else begin
              bi <= bi + 3'd1;
            end
          end else begin
            bj <= bj + 3'd1;
          end
        end

        // -------------------------------------------------------------------
        // Load edges: capture input to temp regs, then apply in next state
        S_BUILD_LOAD: begin
          if (edge_idx < m_reg) begin
            e_p <= p[edge_idx];
            e_q <= q[edge_idx];
            e_c <= c[edge_idx];
          end
        end

        // -------------------------------------------------------------------
        // Apply one edge to adjacency matrix (undirected, keep min cost)
        S_BUILD_APPLY: begin
          if (edge_idx < m_reg) begin
            if (e_p < n_reg && e_q < n_reg && e_p != e_q) begin
              if (e_c < adj_cost[e_p][e_q]) begin
                adj_cost[e_p][e_q] <= e_c;
                adj_cost[e_q][e_p] <= e_c;
              end
            end
            edge_idx <= edge_idx + 6'd1;
          end
        end

        // -------------------------------------------------------------------
        // Initialize clique check
        S_CHECK_INIT: begin
          clique_fail <= 1'b0;
          // simple component: initially each node its own and size=1
          for (i=0;i<MAX_N;i=i+1) begin
            if (i < n_reg) begin
              comp_of[i] <= i[2:0];
            end else begin
              comp_of[i] <= 3'd0;
            end
          end
          for (i=0;i<MAX_N;i=i+1) begin
            comp_deg[i] <= 3'd0;
          end
          bi <= 3'd0;
          bj <= 3'd0;
        end

        // -------------------------------------------------------------------
        // Clique / component validation
        // For each pair (i,j<i): if finite edge, unify; if no edge in same
        // component where needed, we will later detect non-clique by degree.
        S_CHECK_RUN: begin
          if (bi < n_reg) begin
            if (bj < n_reg) begin
              if (bj < bi) begin
                if (adj_cost[bi][bj] != INF14) begin
                  // union-by-small-index
                  if (comp_of[bi] != comp_of[bj]) begin
                    reg [2:0] src; reg [2:0] dst;
                    if (comp_of[bi] < comp_of[bj]) begin
                      src = comp_of[bj];
                      dst = comp_of[bi];
                    end else begin
                      src = comp_of[bi];
                      dst = comp_of[bj];
                    end
                    for (i=0;i<MAX_N;i=i+1) begin
                      if (comp_of[i] == src) comp_of[i] <= dst;
                    end
                  end
                end
              end

              // increment indices
              if (bj == n_reg-1) begin
                bj <= 3'd0;
                bi <= bi + 3'd1;
              end else begin
                bj <= bj + 3'd1;
              end
            end
          end else begin
            // After union, compute sizes and verify each component forms clique
            for (i=0;i<n_reg;i=i+1) begin
              comp_deg[i] <= 3'd0;
            end
            for (i=0;i<n_reg;i=i+1) begin
              comp_deg[comp_of[i]] <= comp_deg[comp_of[i]] + 3'd1;
            end
            // check: for any pair in same comp, must have edge
            clique_fail <= 1'b0;
            for (i=0;i<n_reg;i=i+1) begin
              for (j=i+1;j<n_reg;j=j+1) begin
                if (comp_of[i]==comp_of[j]) begin
                  if (adj_cost[i][j] == INF14) begin
                    clique_fail <= 1'b1;
                  end
                end
              end
            end
          end
        end

        // -------------------------------------------------------------------
        // Initialize matching enumeration
        S_MATCH_INIT: begin
          used_mask     <= 8'd0;
          cur_sum       <= 16'd0;
          best_sum      <= 16'hFFFF;
          have_solution <= 1'b0;
          stack_idx     <= 3'd0;
          backtrack     <= 1'b0;
          // No explicit init of cur_i/cur_j; will be set when needed
        end

        // -------------------------------------------------------------------
        // Enumerate pairings via depth-first search using iterative FSM
        // S_MATCH_ENUM: choose next free i and try partner j
        S_MATCH_ENUM: begin
          if (stack_idx == (n_reg>>1)) begin
            // full matching formed; evaluate
          end else begin
            if (!backtrack) begin
              // find smallest unused i
              reg [2:0] fi;
              reg       found_i;
              fi = 3'd0;
              found_i = 1'b0;
              while (fi < n_reg && !found_i) begin
                if (!used_mask[fi]) begin
                  found_i = 1'b1;
                end else begin
                  fi = fi + 3'd1;
                end
              end
              if (!found_i) begin
                backtrack <= 1'b1;
              end else begin
                cur_i[stack_idx] <= fi;
                // initial j candidate > i
                reg [2:0] init_j;
                init_j = fi + 3'd1;
                cur_j[stack_idx] <= init_j;
              end
            end else begin
              // on backtrack, advance j for current depth handled in EVAL state
            end
          end
        end

        // -------------------------------------------------------------------
        // Evaluate current depth step: try (i,j), or backtrack when exhausted
        S_MATCH_EVAL: begin
          if (stack_idx == (n_reg>>1)) begin
            // full matching: record solution
            if (!have_solution || cur_sum < best_sum) begin
              best_sum      <= cur_sum;
              have_solution <= 1'b1;
            end
            // trigger backtrack
            backtrack <= 1'b1;
            if (stack_idx > 0) begin
              stack_idx <= stack_idx - 3'd1;
            end
          end else begin
            reg [2:0] i_sel;
            reg [2:0] j_sel;
            i_sel = cur_i[stack_idx];
            j_sel = cur_j[stack_idx];

            if (!backtrack) begin
              // try find a valid j
              reg valid_found;
              valid_found = 1'b0;
              while (j_sel < n_reg && !valid_found) begin
                if (!used_mask[j_sel] && adj_cost[i_sel][j_sel] != INF14) begin
                  valid_found = 1'b1;
                end else begin
                  j_sel = j_sel + 3'd1;
                end
              end

              if (valid_found) begin
                // commit this pair
                cur_j[stack_idx] <= j_sel;
                used_mask[i_sel] <= 1'b1;
                used_mask[j_sel] <= 1'b1;
                cur_sum          <= cur_sum + adj_cost[i_sel][j_sel];
                stack_idx        <= stack_idx + 3'd1;
                backtrack        <= 1'b0;
              end else begin
                // no j possible at this depth -> backtrack
                backtrack <= 1'b1;
                if (stack_idx == 0) begin
                  // all done, no more combos
                  backtrack <= 1'b1;
                end else begin
                  stack_idx <= stack_idx - 3'd1;
                end
              end
            end else begin
              // We are backtracking from a deeper level; remove last pair and advance j
              if (stack_idx < (n_reg>>1)) begin
                i_sel = cur_i[stack_idx];
                j_sel = cur_j[stack_idx];
                // remove previous pair if it was committed (check mask bits)
                if (used_mask[i_sel] && used_mask[j_sel]) begin
                  used_mask[i_sel] <= 1'b0;
                  used_mask[j_sel] <= 1'b0;
                  if (cur_sum >= adj_cost[i_sel][j_sel]) begin
                    cur_sum <= cur_sum - adj_cost[i_sel][j_sel];
                  end else begin
                    cur_sum <= 16'd0;
                  end
                end
                // advance j for this depth
                j_sel = j_sel + 3'd1;
                cur_j[stack_idx] <= j_sel;
                backtrack <= 1'b0;
              end else begin
                backtrack <= 1'b1;
              end
            end
          end
        end

        // -------------------------------------------------------------------
        S_DONE: begin
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // Next-state logic
  // ---------------------------------------------------------------------------
  always @(*) begin
    next_state = state;

    case (state)
      S_IDLE: begin
        if (start) begin
          if (n == 3'd0) begin
            next_state = S_DONE;
          end else if (n[0]) begin
            // odd n -> impossible
            next_state = S_DONE;
          end else begin
            next_state = S_INIT;
          end
        end
      end

      S_INIT: begin
        if (bi == MAX_N-1 && bj == MAX_N-1) begin
          if (m_reg == 3'd0) begin
            next_state = S_CHECK_INIT;
          end else begin
            next_state = S_BUILD_LOAD;
          end
        end else begin
          next_state = S_INIT;
        end
      end

      S_BUILD_LOAD: begin
        if (edge_idx < m_reg) begin
          next_state = S_BUILD_APPLY;
        end else begin
          next_state = S_CHECK_INIT;
        end
      end

      S_BUILD_APPLY: begin
        if (edge_idx < m_reg) begin
          next_state = S_BUILD_LOAD;
        end else begin
          next_state = S_CHECK_INIT;
        end
      end

      S_CHECK_INIT: begin
        // move immediately to run union / clique build
        next_state = S_CHECK_RUN;
      end

      S_CHECK_RUN: begin
        if (bi >= n_reg) begin
          // after unions & clique check synthesized in sequential part
          next_state = S_MATCH_INIT;
        end else begin
          next_state = S_CHECK_RUN;
        end
      end

      S_MATCH_INIT: begin
        if (n_reg == 3'd0) begin
          next_state = S_DONE;
        end else begin
          next_state = S_MATCH_ENUM;
        end
      end

      S_MATCH_ENUM: begin
        if (stack_idx == (n_reg>>1)) begin
          next_state = S_MATCH_EVAL;
        end else if (backtrack && stack_idx == 0) begin
          next_state = S_DONE;
        end else begin
          next_state = S_MATCH_EVAL;
        end
      end

      S_MATCH_EVAL: begin
        if (backtrack && stack_idx == 0) begin
          next_state = S_DONE;
        end else begin
          next_state = S_MATCH_ENUM;
        end
      end

      S_DONE: begin
        if (!start) begin
          next_state = S_IDLE;
        end else begin
          next_state = S_DONE;
        end
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  // ---------------------------------------------------------------------------
  // Output and impossible flag control
  // ---------------------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      impossible <= 1'b0;
      min_co2    <= 16'd0;
    end else begin
      // base cases (n==0 or odd n)
      if (state == S_IDLE && start) begin
        if (n == 3'd0) begin
          impossible <= 1'b1;
          min_co2    <= 16'd0;
        end else if (n[0]) begin
          impossible <= 1'b1;
          min_co2    <= 16'd0;
        end else begin
          impossible <= 1'b0;
          min_co2    <= 16'd0;
        end
      end

      // After clique check and matching
      if (state == S_DONE) begin
        if (n_reg == 3'd0) begin
          impossible <= 1'b1;
          min_co2    <= 16'd0;
        end else if (n_reg[0]) begin
          impossible <= 1'b1;
          min_co2    <= 16'd0;
        end else if (clique_fail) begin
          impossible <= 1'b1;
          min_co2    <= 16'd0;
        end else if (!have_solution) begin
          impossible <= 1'b1;
          min_co2    <= 16'd0;
        end else begin
          impossible <= 1'b0;
          min_co2    <= best_sum;
        end
      end
    end
  end

endmodule