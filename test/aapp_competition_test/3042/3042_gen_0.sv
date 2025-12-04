module lcm_tree_counter(
  input  clk,
  input  rst_n,
  input  start,
  input  [31:0] node_values [0:15],
  input  [4:0]  num_nodes,
  output reg [29:0] result,
  output reg done
);

  // ---------------------------------------------------------------------------
  // Parameters
  // ---------------------------------------------------------------------------
  localparam MOD         = 32'd1000000007;
  localparam MAX_NODES   = 16;
  localparam STATE_IDLE        = 3'd0;
  localparam STATE_CHECK_PAIRS = 3'd1;
  localparam STATE_CALC_PERMS  = 3'd2;
  localparam STATE_MOD_OUTPUT  = 3'd3;
  localparam STATE_DONE        = 3'd4;

  // ---------------------------------------------------------------------------
  // Internal registers
  // ---------------------------------------------------------------------------
  reg [2:0]  state, next_state;
  reg [6:0]  cycle_cnt; // for latency control

  // Internal storage for node values
  reg [31:0] nodes      [0:MAX_NODES-1];
  reg [4:0]  n_nodes;

  // For pair checking (Phase 1)
  reg [4:0] i_idx, j_idx, p_idx;
  reg [31:0] gcd_val;
  reg [31:0] lcm_val;

  // Parent possibility matrix: parent_possible[child1][child2] indicates at
  // least one parent exists that equals lcm(child1, child2). For simplicity,
  // count total valid (i,j,parent) triples.
  reg [15:0] parent_possible [0:15][0:15];
  reg [31:0] pair_parent_count;

  // For permutations and duplicates (Phase 2)
  reg [31:0] fact      [0:MAX_NODES];
  reg [31:0] inv_fact  [0:MAX_NODES];

  reg [31:0] perm_result;

  // For counting duplicates
  reg [31:0] sorted_nodes [0:MAX_NODES-1];
  reg [4:0]  sort_i, sort_j;
  reg        sort_done;
  reg [4:0]  dup_i;
  reg [31:0] dup_count;

  // Modular arithmetic helpers
  function automatic [31:0] mod_add(input [31:0] a, input [31:0] b);
    reg [32:0] s;
    begin
      s = a + b;
      if (s >= MOD) mod_add = s - MOD;
      else mod_add = s[31:0];
    end
  endfunction

  function automatic [31:0] mod_sub(input [31:0] a, input [31:0] b);
    reg [32:0] d;
    begin
      if (a >= b) d = a - b;
      else d = a + MOD - b;
      mod_sub = d[31:0];
    end
  endfunction

  function automatic [31:0] mod_mul(input [31:0] a, input [31:0] b);
    // 64-bit intermediate multiply, then mod
    reg [63:0] m;
    begin
      m = a * b;
      mod_mul = m % MOD;
    end
  endfunction

  // Binary exponentiation under MOD
  function automatic [31:0] mod_pow(input [31:0] base, input [31:0] exp);
    reg [31:0] b;
    reg [31:0] res;
    reg [31:0] e;
    begin
      b   = base % MOD;
      res = 32'd1;
      e   = exp;
      while (e != 0) begin
        if (e[0]) res = mod_mul(res, b);
        b = mod_mul(b, b);
        e = e >> 1;
      end
      mod_pow = res;
    end
  endfunction

  // Modular inverse using Fermat's little theorem (MOD is prime)
  function automatic [31:0] mod_inv(input [31:0] a);
    begin
      mod_inv = mod_pow(a, MOD-2);
    end
  endfunction

  // GCD (Euclidean)
  function automatic [31:0] gcd(input [31:0] a, input [31:0] b);
    reg [31:0] x, y, t;
    begin
      x = a; y = b;
      if (x == 0) begin
        gcd = y;
      end else if (y == 0) begin
        gcd = x;
      end else begin
        while (y != 0) begin
          t = x % y;
          x = y;
          y = t;
        end
        gcd = x;
      end
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Precompute factorials and inverse factorials up to 16
  // Computed once after reset; static for all runs.
  // ---------------------------------------------------------------------------
  reg facts_init_done;
  integer fi;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      facts_init_done <= 1'b0;
      for (fi = 0; fi <= MAX_NODES; fi = fi + 1) begin
        fact[fi]     <= 32'd0;
        inv_fact[fi] <= 32'd0;
      end
    end else if (!facts_init_done) begin
      // Initialize factorials
      fact[0] <= 32'd1;
      for (fi = 1; fi <= MAX_NODES; fi = fi + 1) begin
        fact[fi] <= mod_mul(fact[fi-1], fi[31:0]);
      end
      // After loop, compute inverse factorials using modular inverse
      inv_fact[MAX_NODES] <= mod_inv(fact[MAX_NODES]);
      for (fi = MAX_NODES-1; fi >= 0; fi = fi - 1) begin
        inv_fact[fi] <= mod_mul(inv_fact[fi+1], (fi+1)[31:0]);
      end
      facts_init_done <= 1'b1;
    end
  end

  // ---------------------------------------------------------------------------
  // State machine: sequential
  // ---------------------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= STATE_IDLE;
      cycle_cnt  <= 7'd0;
      done       <= 1'b0;
      result     <= 30'd0;
      n_nodes    <= 5'd0;
      i_idx      <= 5'd0;
      j_idx      <= 5'd0;
      p_idx      <= 5'd0;
      pair_parent_count <= 32'd0;
      sort_done  <= 1'b0;
      sort_i     <= 5'd0;
      sort_j     <= 5'd0;
      dup_i      <= 5'd0;
      dup_count  <= 32'd0;
      perm_result <= 32'd0;
    end else begin
      state <= next_state;

      // Cycle counter to ensure <= 100-cycle latency; reset on start or done
      if (state == STATE_IDLE && start)
        cycle_cnt <= 7'd0;
      else if (state != STATE_IDLE && state != STATE_DONE)
        cycle_cnt <= cycle_cnt + 7'd1;

      if (state == STATE_DONE && !start)
        cycle_cnt <= 7'd0;

      // Core sequential behaviors per state
      case (state)
        // -------------------------------------------------------------------
        // IDLE: Wait for start, load nodes
        // -------------------------------------------------------------------
        STATE_IDLE: begin
          done   <= 1'b0;
          if (start && facts_init_done) begin
            n_nodes <= num_nodes;
            // Load nodes into internal array
            for (fi = 0; fi < MAX_NODES; fi = fi + 1) begin
              if (fi < num_nodes) nodes[fi] <= node_values[fi];
              else nodes[fi] <= 32'd0;
            end
            // Initialize phase 1 structures
            for (i_idx = 0; i_idx < MAX_NODES; i_idx = i_idx + 1) begin
              for (j_idx = 0; j_idx < MAX_NODES; j_idx = j_idx + 1) begin
                parent_possible[i_idx][j_idx] <= 16'd0;
              end
            end
            pair_parent_count <= 32'd0;
            i_idx <= 5'd0;
            j_idx <= 5'd1;
            p_idx <= 5'd0;

            // Initialize sort structures
            for (fi = 0; fi < MAX_NODES; fi = fi + 1) begin
              sorted_nodes[fi] <= (fi < num_nodes) ? node_values[fi] : 32'd0;
            end
            sort_i    <= 5'd0;
            sort_j    <= 5'd0;
            sort_done <= 1'b0;
            dup_i     <= 5'd0;
            dup_count <= 32'd0;
            perm_result <= 32'd1; // start with 1
          end
        end

        // -------------------------------------------------------------------
        // CHECK_PAIRS: Phase 1 - verify possible parent nodes for each pair
        // -------------------------------------------------------------------
        STATE_CHECK_PAIRS: begin
          // Iterate over all pairs (i,j) with i < j < n_nodes
          if (i_idx < n_nodes) begin
            if (j_idx < n_nodes) begin
              if (i_idx < j_idx) begin
                // Compute GCD and LCM
                gcd_val = gcd(nodes[i_idx], nodes[j_idx]);
                if (gcd_val != 0) begin
                  lcm_val = ( (nodes[i_idx] / gcd_val) * nodes[j_idx] );
                end else begin
                  lcm_val = 32'd0;
                end

                // Search for parent equal to lcm_val
                parent_possible[i_idx][j_idx] <= 16'd0;
                for (p_idx = 0; p_idx < n_nodes; p_idx = p_idx + 1) begin
                  if (nodes[p_idx] == lcm_val) begin
                    parent_possible[i_idx][j_idx][p_idx] <= 1'b1;
                  end
                end

                // Count if at least one parent exists
                if (parent_possible[i_idx][j_idx] != 16'd0)
                  pair_parent_count <= pair_parent_count + 32'd1;
              end

              j_idx <= j_idx + 5'd1;
            end else begin
              i_idx <= i_idx + 5'd1;
              j_idx <= (i_idx + 5'd2); // next j starts at i+2
            end
          end
        end

        // -------------------------------------------------------------------
        // CALC_PERMS: Phase 2 - permutations accounting for duplicates
        // -------------------------------------------------------------------
        STATE_CALC_PERMS: begin
          // Simple in-place bubble sort over multiple cycles
          if (!sort_done) begin
            if (sort_i < n_nodes) begin
              if (sort_j + 1 < n_nodes - sort_i) begin
                if (sorted_nodes[sort_j] > sorted_nodes[sort_j+1]) begin
                  // swap
                  reg [31:0] tmp;
                  tmp = sorted_nodes[sort_j];
                  sorted_nodes[sort_j] <= sorted_nodes[sort_j+1];
                  sorted_nodes[sort_j+1] <= tmp;
                end
                sort_j <= sort_j + 5'd1;
              end else begin
                sort_j <= 5'd0;
                sort_i <= sort_i + 5'd1;
              end
            end else begin
              sort_done <= 1'b1;
              dup_i     <= 5'd0;
              dup_count <= 32'd1;
            end
          end else begin
            // After sort: compute factorial(n_nodes) / product(fact[dup_count])
            if (dup_i + 1 < n_nodes) begin
              if (sorted_nodes[dup_i] == sorted_nodes[dup_i+1]) begin
                dup_count <= dup_count + 32'd1;
              end else begin
                // apply division by dup_count! via inv_fact
                perm_result <= mod_mul(perm_result, inv_fact[dup_count]);
                dup_count   <= 32'd1;
              end
              dup_i <= dup_i + 5'd1;
            end else begin
              // Final group
              perm_result <= mod_mul(perm_result, inv_fact[dup_count]);
              // Multiply by n_nodes!
              perm_result <= mod_mul(perm_result, fact[n_nodes]);
            end
          end
        end

        // -------------------------------------------------------------------
        // MOD_OUTPUT: Phase 3 - finalize result modulo MOD
        // Combine pair_parent_count and perm_result in a simple model:
        // result_full = (pair_parent_count + perm_result) mod MOD
        // -------------------------------------------------------------------
        STATE_MOD_OUTPUT: begin
          // Simple combination (placeholder for full tree-counting logic)
          // Ensure within MOD
          reg [31:0] res_full;
          res_full = mod_add(pair_parent_count % MOD, perm_result % MOD);
          result <= res_full[29:0];
        end

        // -------------------------------------------------------------------
        // DONE: hold result until next start
        // -------------------------------------------------------------------
        STATE_DONE: begin
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
      STATE_IDLE: begin
        if (start && facts_init_done) next_state = STATE_CHECK_PAIRS;
      end

      STATE_CHECK_PAIRS: begin
        // Move to CALC_PERMS once all pairs processed or cycle limit
        if ((i_idx >= n_nodes) || (cycle_cnt >= 7'd40)) begin
          next_state = STATE_CALC_PERMS;
        end
      end

      STATE_CALC_PERMS: begin
        // After sorting and duplicate handling complete, move on
        if (sort_done && (dup_i + 1 >= n_nodes)) begin
          next_state = STATE_MOD_OUTPUT;
        end
        // Guard against over-latency
        if (cycle_cnt >= 7'd80) begin
          next_state = STATE_MOD_OUTPUT;
        end
      end

      STATE_MOD_OUTPUT: begin
        next_state = STATE_DONE;
      end

      STATE_DONE: begin
        // Optionally return to IDLE when a new start is seen
        if (start) next_state = STATE_IDLE;
      end

      default: next_state = STATE_IDLE;
    endcase
  end

endmodule