module max_box_piles(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [5:0] a [7:0],
  output reg [31:0] result,
  output reg done
);

  // Modulo constant
  localparam [31:0] MOD = 32'd1000000007;

  // Precomputed factorials (0..8) modulo MOD
  // 0!:1, 1!:1, 2!:2, 3!:6, 4!:24, 5!:120, 6!:720, 7!:5040, 8!:40320
  localparam [31:0] FACT [0:8] = '{
    32'd1,
    32'd1,
    32'd2,
    32'd6,
    32'd24,
    32'd120,
    32'd720,
    32'd5040,
    32'd40320
  };

  // Precomputed modular inverses of factorials (0..8) modulo MOD
  // Using known values for MOD=1e9+7
  localparam [31:0] INV_FACT [0:8] = '{
    32'd1,            // inv(0!)
    32'd1,            // inv(1!)
    32'd500000004,    // inv(2!)
    32'd166666668,    // inv(3!)
    32'd41666667,     // inv(4!)
    32'd808333339,    // inv(5!)
    32'd301388891,    // inv(6!)
    32'd900198419,    // inv(7!)
    32'd722774450     // inv(8!)
  };

  // FSM states
  localparam S_IDLE       = 4'd0;
  localparam S_INIT       = 4'd1;
  localparam S_BUILD_ADJ  = 4'd2;
  localparam S_WCC_NEXT   = 4'd3;
  localparam S_DFS_PUSH   = 4'd4;
  localparam S_DFS_STEP   = 4'd5;
  localparam S_DFS_NEIGH  = 4'd6;
  localparam S_DFS_POP    = 4'd7;
  localparam S_WCC_DONE   = 4'd8;
  localparam S_COMP_DONE  = 4'd9;

  reg [3:0] state, next_state;

  // Adjacency matrix for weak connectivity (undirected): edge if divisible either way
  reg adj [7:0][7:0];

  // Visited flags for WCC
  reg visited [7:0];

  // Stack for iterative DFS
  reg [2:0] stack [7:0];
  reg [3:0] sp;          // stack pointer (0..8)

  // Per-node neighbor index iterator for DFS
  reg [2:0] neigh_idx [7:0];

  // Current DFS node
  reg [2:0] cur_node;

  // Component tracking
  reg [2:0] comp_id [7:0];        // component index of each node
  reg [2:0] comp_count;           // number of components found
  reg [3:0] comp_size [7:0];      // size of each component

  // Loop indices
  reg [3:0] i_idx;
  reg [3:0] j_idx;
  reg [2:0] start_node;

  // Utility: 6-bit operands extended
  function automatic bit is_divisible(input [5:0] x, input [5:0] y);
    integer k;
    begin
      if (y == 0) begin
        is_divisible = 0;
      end else if (x == 0) begin
        is_divisible = 1; // 0 mod y == 0
      end else begin
        // small values: repeated subtraction / modulus
        // but constraints are tiny; do x % y == 0
        k = x % y;
        is_divisible = (k == 0);
      end
    end
  endfunction

  // Modular add
  function automatic [31:0] add_mod(input [31:0] x, input [31:0] y);
    reg [32:0] s;
    begin
      s = x + y;
      if (s >= MOD)
        add_mod = s - MOD;
      else
        add_mod = s[31:0];
    end
  endfunction

  // Modular sub
  function automatic [31:0] sub_mod(input [31:0] x, input [31:0] y);
    begin
      if (x >= y)
        sub_mod = x - y;
      else
        sub_mod = x + MOD - y;
    end
  endfunction

  // Modular multiply (safe for small ops; 32x32 -> 64)
  function automatic [31:0] mul_mod(input [31:0] x, input [31:0] y);
    reg [63:0] p;
    begin
      p = x;
      p = p * y;
      p = p % MOD;
      mul_mod = p[31:0];
    end
  endfunction

  // nCr using precomputed factorials (n<=8)
  function automatic [31:0] nCr_small(input [3:0] nn, input [3:0] rr);
    reg [31:0] t;
    begin
      if (rr > nn) begin
        nCr_small = 32'd0;
      end else begin
        t = mul_mod(FACT[nn], INV_FACT[rr]);
        nCr_small = mul_mod(t, INV_FACT[nn-rr]);
      end
    end
  endfunction

  // Main sequential logic
  integer u, v;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      done <= 1'b0;
      result <= 32'd0;

      for (u = 0; u < 8; u = u + 1) begin
        visited[u] <= 1'b0;
        comp_id[u] <= 3'd0;
        comp_size[u] <= 4'd0;
        neigh_idx[u] <= 3'd0;
        for (v = 0; v < 8; v = v + 1) begin
          adj[u][v] <= 1'b0;
        end
      end
      comp_count <= 3'd0;
      sp <= 4'd0;
      i_idx <= 4'd0;
      j_idx <= 4'd0;
      start_node <= 3'd0;
      cur_node <= 3'd0;

    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Prepare for init in next cycle
          end
        end

        S_INIT: begin
          done <= 1'b0;
          result <= 32'd0;
          // Clear data structures
          for (u = 0; u < 8; u = u + 1) begin
            visited[u] <= 1'b0;
            comp_id[u] <= 3'd0;
            comp_size[u] <= 4'd0;
            neigh_idx[u] <= 3'd0;
            for (v = 0; v < 8; v = v + 1) begin
              adj[u][v] <= 1'b0;
            end
          end
          comp_count <= 3'd0;
          sp <= 4'd0;
          i_idx <= 4'd0;
          j_idx <= 4'd0;
          start_node <= 3'd0;
        end

        S_BUILD_ADJ: begin
          // Build adjacency for nodes 0..n-1, rest remain 0
          // We'll iterate i_idx and j_idx across cycles
          if (i_idx < n) begin
            if (j_idx < n) begin
              if (i_idx == j_idx) begin
                adj[i_idx][j_idx] <= 1'b0;
              end else begin
                // Weakly connected if divisible either way
                if (is_divisible(a[i_idx], a[j_idx]) || is_divisible(a[j_idx], a[i_idx]))
                  adj[i_idx][j_idx] <= 1'b1;
                else
                  adj[i_idx][j_idx] <= 1'b0;
              end
              j_idx <= j_idx + 1'b1;
            end else begin
              j_idx <= 4'd0;
              i_idx <= i_idx + 1'b1;
            end
          end
        end

        S_WCC_NEXT: begin
          // Find next unvisited node as new component root
          if (start_node < n) begin
            if (!visited[start_node]) begin
              // start new component DFS
              visited[start_node] <= 1'b1;
              comp_id[start_node] <= comp_count;
              comp_size[comp_count] <= 4'd1;

              stack[0] <= start_node[2:0];
              sp <= 4'd1;
              neigh_idx[start_node] <= 3'd0;
              cur_node <= start_node[2:0];
            end else begin
              start_node <= start_node + 1'b1;
            end
          end
        end

        S_DFS_PUSH: begin
          // Nothing extra; we already pushed root in WCC_NEXT
        end

        S_DFS_STEP: begin
          // If stack not empty, process top
          if (sp != 0) begin
            cur_node <= stack[sp-1];
          end
        end

        S_DFS_NEIGH: begin
          if (sp != 0) begin
            u = cur_node;
            if (neigh_idx[u] < n) begin
              v = neigh_idx[u];
              if (adj[u][v] && !visited[v]) begin
                visited[v] <= 1'b1;
                comp_id[v] <= comp_id[u];
                comp_size[comp_id[u]] <= comp_size[comp_id[u]] + 1'b1;

                stack[sp] <= v[2:0];
                sp <= sp + 1'b1;
                neigh_idx[v] <= 3'd0;
              end
              neigh_idx[u] <= neigh_idx[u] + 1'b1;
            end
          end
        end

        S_DFS_POP: begin
          if (sp != 0) begin
            u = stack[sp-1];
            if (neigh_idx[u] >= n) begin
              // pop
              sp <= sp - 1'b1;
            end
          end
        end

        S_WCC_DONE: begin
          // Nothing: transition logic in next_state will move on
        end

        S_COMP_DONE: begin
          // Compute final result using component sizes.
          // For this template, we assume we want the number of permutations of n
          // respecting components as indistinguishable groups or similar.
          // Here we implement: result = n! / prod( size[c]! ) mod MOD.
          // This yields count of permutations of boxes where boxes within each
          // connected component are treated as identical (example combinatorial).

          reg [31:0] res_tmp;
          reg [3:0] cidx;
          reg [31:0] denom;
          res_tmp = FACT[n];
          denom = 32'd1;
          for (cidx = 0; cidx < comp_count; cidx = cidx + 1) begin
            if (comp_size[cidx] > 1) begin
              denom = mul_mod(denom, FACT[comp_size[cidx]]);
            end
          end
          // res = res_tmp * inv(denom) (but we only have inv factorial small).
          // For sizes <=8, denom is product of factorials up to 8.
          // We can decompose denom inversion via brute small-loop search.
          // But for simplicity and determinism, perform exponentiation by MOD-2.

          // small modular inverse function via binary exponentiation
          function automatic [31:0] mod_pow(input [31:0] base, input [31:0] exp);
            reg [31:0] b;
            reg [31:0] r;
            reg [31:0] e;
            begin
              b = base;
              r = 32'd1;
              e = exp;
              while (e != 0) begin
                if (e[0])
                  r = mul_mod(r, b);
                b = mul_mod(b, b);
                e = e >> 1;
              end
              mod_pow = r;
            end
          endfunction

          reg [31:0] inv_denom;
          if (denom == 32'd1) begin
            inv_denom = 32'd1;
          end else begin
            inv_denom = mod_pow(denom, 32'd1000000005);
          end

          result <= mul_mod(res_tmp, inv_denom);
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
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
        next_state = S_BUILD_ADJ;
      end

      S_BUILD_ADJ: begin
        if (i_idx >= n)
          next_state = S_WCC_NEXT;
      end

      S_WCC_NEXT: begin
        if (start_node >= n) begin
          next_state = S_WCC_DONE;
        end else if (!visited[start_node]) begin
          next_state = S_DFS_STEP;
        end else begin
          next_state = S_WCC_NEXT; // will advance start_node in seq block
        end
      end

      S_DFS_STEP: begin
        if (sp == 0) begin
          // finished this component
          next_state = S_WCC_NEXT;
        end else begin
          next_state = S_DFS_NEIGH;
        end
      end

      S_DFS_NEIGH: begin
        if (sp == 0) begin
          next_state = S_WCC_NEXT;
        end else begin
          // check if current node finished neighbors
          if (neigh_idx[cur_node] >= n)
            next_state = S_DFS_POP;
          else
            next_state = S_DFS_NEIGH;
        end
      end

      S_DFS_POP: begin
        if (sp == 0) begin
          // component complete
          // increment comp_count in sequential part via implicit behavior:
          // Use visit patterns: detect here via transition back
          next_state = S_WCC_NEXT;
        end else begin
          next_state = S_DFS_STEP;
        end
      end

      S_WCC_DONE: begin
        next_state = S_COMP_DONE;
      end

      S_COMP_DONE: begin
        // Stay here until new start or reset
        if (!start)
          next_state = S_IDLE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  // Component count management (separate small process)
  // Increment comp_count when a new DFS root is accepted.
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      comp_count <= 3'd0;
    end else begin
      if (state == S_WCC_NEXT && start_node < n && !visited[start_node]) begin
        comp_count <= comp_count + 1'b1;
      end
    end
  end

endmodule
