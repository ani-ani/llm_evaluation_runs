module constrained_mst (
  input clk,
  input rst_n,
  input start,
  // Configuration
  input [2:0] num_nodes,
  input [3:0] num_edges,
  input [2:0] num_special,
  input [2:0] required_mix_edges,
  // Special nodes (3-bit IDs)
  input [2:0] special1,
  input [2:0] special2,
  input [2:0] special3,
  // Edge list (8 edges max)
  input [2:0] edge1_a,  input [2:0] edge1_b,  input [6:0] edge1_cost,
  input [2:0] edge2_a,  input [2:0] edge2_b,  input [6:0] edge2_cost,
  input [2:0] edge3_a,  input [2:0] edge3_b,  input [6:0] edge3_cost,
  input [2:0] edge4_a,  input [2:0] edge4_b,  input [6:0] edge4_cost,
  input [2:0] edge5_a,  input [2:0] edge5_b,  input [6:0] edge5_cost,
  input [2:0] edge6_a,  input [2:0] edge6_b,  input [6:0] edge6_cost,
  input [2:0] edge7_a,  input [2:0] edge7_b,  input [6:0] edge7_cost,
  input [2:0] edge8_a,  input [2:0] edge8_b,  input [6:0] edge8_cost,
  output reg [10:0] total_cost,
  output reg done,
  output reg error
);

  // Local parameters
  parameter MAX_NODES = 8;
  parameter MAX_EDGES = 8;
  parameter CNT_W = $clog2(MAX_NODES+1); // 4 bits is enough
  parameter CYC_LIMIT = 128; // 128-cycle budget

  // Edge representation
  typedef struct packed {
    logic [2:0] u;
    logic [2:0] v;
    logic [6:0] cost;
    logic       is_mix;   // 1 if connects special <-> regular, 0 otherwise
    logic       valid;   // 1 if edge exists (within num_edges)
  } edge_t;

  // Union-Find (UFDS) for up to 8 nodes
  logic [2:0] parent_r [0:MAX_NODES-1];
  logic [CNT_W-1:0] rank_r [0:MAX_NODES-1];
  logic [2:0] parent_nxt [0:MAX_NODES-1];
  logic [CNT_W-1:0] rank_nxt [0:MAX_NODES-1];

  // Edge buffer
  edge_t edges_r [0:MAX_EDGES-1];
  edge_t edges_nxt [0:MAX_EDGES-1];

  // State machine
  typedef enum logic [3:0] {
    S_IDLE     = 4'd0,
    S_SORT1    = 4'd1,
    S_SORT2    = 4'd2,
    S_KRUSKAL  = 4'd3,
    S_DONE     = 4'd4,
    S_ERROR    = 4'd5
  } state_t;
  state_t state_r, state_nxt;

  // Control and counters
  logic [6:0] cycle_cnt_r, cycle_cnt_nxt;
  logic [$clog2(MAX_EDGES+1)-1:0] i_r, i_nxt; // general iterator
  logic [2:0] selected_edges_r, selected_edges_nxt; // edges selected (should reach num_nodes-1)
  logic [2:0] mix_selected_r, mix_selected_nxt;     // special<->regular edges selected
  logic valid_solution;

  // Helper: find with path compression
  function [2:0] find_root;
    input [2:0] x;
    begin
      if (parent_r[x] == x) find_root = x;
      else find_root = find_root(parent_r[x]);
    end
  endfunction

  function logic same_set;
    input [2:0] a, b;
    begin
      same_set = (find_root(a) == find_root(b));
    end
  endfunction

  function void union_sets;
    input [2:0] a, b;
    input [2:0] ra, rb; // precomputed roots
    // Update in nxt arrays; assumed to be applied to parent_nxt/rank_nxt
    if (ra == rb) begin
      // no-op
    end else if (rank_nxt[ra] < rank_nxt[rb]) begin
      parent_nxt[ra] = rb;
    end else if (rank_nxt[ra] > rank_nxt[rb]) begin
      parent_nxt[rb] = ra;
    end else begin
      parent_nxt[rb] = ra;
      rank_nxt[ra] = rank_nxt[ra] + 1;
    end
  endfunction

  // Set membership helper for specials
  function logic is_special;
    input [2:0] id;
    input [2:0] s1, s2, s3;
    input [2:0] nspec;
    begin
      is_special = 1'b0;
      if (nspec >= 3'd1 && id == s1) is_special = 1'b1;
      if (nspec >= 3'd2 && id == s2) is_special = 1'b1;
      if (nspec >= 3'd3 && id == s3) is_special = 1'b1;
    end
  endfunction

  // Load edges from inputs and compute mix flags
  task load_edges;
    input [2:0] nspec;
    input [2:0] s1, s2, s3;
  endtask

  task automatic load_edges;
    input [2:0] nspec;
    input [2:0] s1, s2, s3;
    begin
      // Use generate-style manual unrolling for SV-2009 compatibility in some tools
      edges_nxt[0] = edge_t'{
        u: edge1_a, v: edge1_b, cost: edge1_cost,
        is_mix: (is_special(edge1_a, s1, s2, s3, nspec) ^ is_special(edge1_b, s1, s2, s3, nspec)) && (is_special(edge1_a, s1, s2, s3, nspec) || is_special(edge1_b, s1, s2, s3, nspec)),
        valid: 1'b1
      };
      edges_nxt[1] = edge_t'{
        u: edge2_a, v: edge2_b, cost: edge2_cost,
        is_mix: (is_special(edge2_a, s1, s2, s3, nspec) ^ is_special(edge2_b, s1, s2, s3, nspec)) && (is_special(edge2_a, s1, s2, s3, nspec) || is_special(edge2_b, s1, s2, s3, nspec)),
        valid: 1'b1
      };
      edges_nxt[2] = edge_t'{
        u: edge3_a, v: edge3_b, cost: edge3_cost,
        is_mix: (is_special(edge3_a, s1, s2, s3, nspec) ^ is_special(edge3_b, s1, s2, s3, nspec)) && (is_special(edge3_a, s1, s2, s3, nspec) || is_special(edge3_b, s1, s2, s3, nspec)),
        valid: 1'b1
      };
      edges_nxt[3] = edge_t'{
        u: edge4_a, v: edge4_b, cost: edge4_cost,
        is_mix: (is_special(edge4_a, s1, s2, s3, nspec) ^ is_special(edge4_b, s1, s2, s3, nspec)) && (is_special(edge4_a, s1, s2, s3, nspec) || is_special(edge4_b, s1, s2, s3, nspec)),
        valid: 1'b1
      };
      edges_nxt[4] = edge_t'{
        u: edge5_a, v: edge5_b, cost: edge5_cost,
        is_mix: (is_special(edge5_a, s1, s2, s3, nspec) ^ is_special(edge5_b, s1, s2, s3, nspec)) && (is_special(edge5_a, s1, s2, s3, nspec) || is_special(edge5_b, s1, s2, s3, nspec)),
        valid: 1'b1
      };
      edges_nxt[5] = edge_t'{
        u: edge6_a, v: edge6_b, cost: edge6_cost,
        is_mix: (is_special(edge6_a, s1, s2, s3, nspec) ^ is_special(edge6_b, s1, s2, s3, nspec)) && (is_special(edge6_a, s1, s2, s3, nspec) || is_special(edge6_b, s1, s2, s3, nspec)),
        valid: 1'b1
      };
      edges_nxt[6] = edge_t'{
        u: edge7_a, v: edge7_b, cost: edge7_cost,
        is_mix: (is_special(edge7_a, s1, s2, s3, nspec) ^ is_special(edge7_b, s1, s2, s3, nspec)) && (is_special(edge7_a, s1, s2, s3, nspec) || is_special(edge7_b, s1, s2, s3, nspec)),
        valid: 1'b1
      };
      edges_nxt[7] = edge_t'{
        u: edge8_a, v: edge8_b, cost: edge8_cost,
        is_mix: (is_special(edge8_a, s1, s2, s3, nspec) ^ is_special(edge8_b, s1, s2, s3, nspec)) && (is_special(edge8_a, s1, s2, s3, nspec) || is_special(edge8_b, s1, s2, s3, nspec)),
        valid: 1'b1
      };
      // Mask out edges beyond num_edges by setting valid=0
      for (int k = 0; k < MAX_EDGES; k++) begin
        if (k >= num_edges) edges_nxt[k].valid = 1'b0;
      end
    end
  endtask

  // Main sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_r <= S_IDLE;
      cycle_cnt_r <= 7'd0;
      i_r <= 3'd0;
      selected_edges_r <= 3'd0;
      mix_selected_r <= 3'd0;
      total_cost <= 11'd0;
      done <= 1'b0;
      error <= 1'b0;
      for (int n = 0; n < MAX_NODES; n++) begin
        parent_r[n] <= n[2:0];
        rank_r[n] <= 2'd0;
      end
      for (int e = 0; e < MAX_EDGES; e++) begin
        edges_r[e] <= edge_t'{default: '0};
      end
    end else begin
      state_r <= state_nxt;
      cycle_cnt_r <= cycle_cnt_nxt;
      i_r <= i_nxt;
      selected_edges_r <= selected_edges_nxt;
      mix_selected_r <= mix_selected_nxt;
      for (int n = 0; n < MAX_NODES; n++) begin
        parent_r[n] <= parent_nxt[n];
        rank_r[n] <= rank_nxt[n];
      end
      for (int e = 0; e < MAX_EDGES; e++) begin
        edges_r[e] <= edges_nxt[e];
      end
      // Outputs are registered
      if (state_nxt == S_DONE) begin
        done <= 1'b1;
        error <= 1'b0;
      end else if (state_nxt == S_ERROR) begin
        done <= 1'b0;
        error <= 1'b1;
      end else begin
        done <= 1'b0;
        error <= 1'b0;
      end
    end
  end

  // Combinational next-state logic
  always_comb begin
    // defaults
    state_nxt = state_r;
    cycle_cnt_nxt = cycle_cnt_r + 1;
    i_nxt = i_r;
    selected_edges_nxt = selected_edges_r;
    mix_selected_nxt = mix_selected_r;
    total_cost = 11'd0;
    for (int n = 0; n < MAX_NODES; n++) begin
      parent_nxt[n] = parent_r[n];
      rank_nxt[n] = rank_r[n];
    end
    for (int e = 0; e < MAX_EDGES; e++) begin
      edges_nxt[e] = edges_r[e];
    end
    valid_solution = 1'b0;

    case (state_r)
      S_IDLE: begin
        cycle_cnt_nxt = 7'd0;
        i_nxt = 3'd0;
        selected_edges_nxt = 3'd0;
        mix_selected_nxt = 3'd0;
        if (start) begin
          // Init UFDS
          for (int n = 0; n < MAX_NODES; n++) begin
            parent_nxt[n] = n[2:0];
            rank_nxt[n] = 2'd0;
          end
          // Load and annotate edges
          load_edges(num_special, special1, special2, special3);
          // Two-phase bubble sort for up to 8 elements: total passes = MAX_EDGES
          state_nxt = S_SORT1;
        end
      end

      S_SORT1: begin
        // Compare-swap edges[i], edges[i+1]
        if (i_r < (MAX_EDGES-1)) begin
          edges_nxt = edges_r; // keep current edges, will swap if needed below
          if (edges_r[i_r].valid && edges_r[i_r+1].valid) begin
            if (edges_r[i_r].cost > edges_r[i_r+1].cost) begin
              edges_nxt[i_r] = edges_r[i_r+1];
              edges_nxt[i_r+1] = edges_r[i_r];
            end
          end else if (edges_r[i_r].valid && !edges_r[i_r+1].valid) begin
            // Valid edges bubble to front: swap to move valid to lower index
            edges_nxt[i_r] = edges_r[i_r+1];
            edges_nxt[i_r+1] = edges_r[i_r];
          end
          i_nxt = i_r + 1;
        end else begin
          // End of pass
          i_nxt = 3'd0;
          state_nxt = S_SORT2;
        end
      end

      S_SORT2: begin
        // Second pass to guarantee bubble-up of all valid edges
        if (i_r < (MAX_EDGES-1)) begin
          edges_nxt = edges_r;
          if (edges_r[i_r].valid && edges_r[i_r+1].valid) begin
            if (edges_r[i_r].cost > edges_r[i_r+1].cost) begin
              edges_nxt[i_r] = edges_r[i_r+1];
              edges_nxt[i_r+1] = edges_r[i_r];
            end
          end else if (edges_r[i_r].valid && !edges_r[i_r+1].valid) begin
            edges_nxt[i_r] = edges_r[i_r+1];
            edges_nxt[i_r+1] = edges_r[i_r];
          end
          i_nxt = i_r + 1;
        end else begin
          i_nxt = 3'd0;
          state_nxt = S_KRUSKAL;
        end
      end

      S_KRUSKAL: begin
        edges_nxt = edges_r;
        selected_edges_nxt = selected_edges_r;
        mix_selected_nxt = mix_selected_r;
        // Reset UFDS at start of selection phase
        if (i_r == 0) begin
          for (int n = 0; n < MAX_NODES; n++) begin
            parent_nxt[n] = n[2:0];
            rank_nxt[n] = 2'd0;
          end
        end
        // Select edges in order if they satisfy constraints
        if (i_r < MAX_EDGES) begin
          if (edges_r[i_r].valid) begin
            if (!same_set(edges_r[i_r].u, edges_r[i_r].v)) begin
              // Tentative inclusion check against required mix edges
              logic will_be_equal;
              will_be_equal = ((mix_selected_r + edges_r[i_r].is_mix) == required_mix_edges);
              if (will_be_equal || (mix_selected_r < required_mix_edges)) begin
                // Accept edge
                union_sets(edges_r[i_r].u, edges_r[i_r].v, find_root(edges_r[i_r].u), find_root(edges_r[i_r].v));
                selected_edges_nxt = selected_edges_r + 1;
                if (edges_r[i_r].is_mix) mix_selected_nxt = mix_selected_r + 1;
              end
              // else: skip this edge to preserve mix count
            end
            // else: would form cycle; skip
          end
          i_nxt = i_r + 1;
        end else begin
          // Done scanning edges
          // Success if selected exactly num_nodes-1 edges and mix count matches
          valid_solution = (selected_edges_r == (num_nodes - 1)) && (mix_selected_r == required_mix_edges);
          if (valid_solution) begin
            total_cost = 11'd0;
            for (int k = 0; k < MAX_EDGES; k++) begin
              if (edges_r[k].valid) begin
                if (!same_set(edges_r[k].u, edges_r[k].v)) begin
                  // The last scan may have not included these already in selected_edges_r;
                  // recompute MST sum using a fresh find on current parents (after selection)
                end
              end
            end
            // Recompute total_cost by re-running union-find selection on sorted edges
            // Reinitialize temporary UFDS to compute sum
            for (int n = 0; n < MAX_NODES; n++) begin
              parent_nxt[n] = n[2:0];
              rank_nxt[n] = 2'd0;
            end
            logic [10:0] sum;
            logic [2:0] sel_cnt;
            logic [2:0] mix_cnt;
            sum = 11'd0;
            sel_cnt = 3'd0;
            mix_cnt = 3'd0;
            for (int k = 0; k < MAX_EDGES; k++) begin
              if (edges_r[k].valid && (sel_cnt < (num_nodes - 1))) begin
                if (!same_set(edges_r[k].u, edges_r[k].v)) begin
                  if ((mix_cnt < required_mix_edges) || (mix_cnt + edges_r[k].is_mix <= required_mix_edges)) begin
                    sum = sum + edges_r[k].cost;
                    sel_cnt = sel_cnt + 1;
                    if (edges_r[k].is_mix) mix_cnt = mix_cnt + 1;
                    union_sets(edges_r[k].u, edges_r[k].v, find_root(edges_r[k].u), find_root(edges_r[k].v));
                  end
                end
              end
            end
            if ((sel_cnt == (num_nodes - 1)) && (mix_cnt == required_mix_edges)) begin
              total_cost = sum;
              state_nxt = S_DONE;
            end else begin
              state_nxt = S_ERROR;
            end
          end else begin
            state_nxt = S_ERROR;
          end
        end
        // Timeout check
        if (cycle_cnt_nxt >= CYC_LIMIT && state_r == S_KRUSKAL) begin
          state_nxt = S_ERROR;
        end
      end

      S_DONE: begin
        // Hold outputs for 1 cycle, then return to IDLE
        state_nxt = S_IDLE;
        cycle_cnt_nxt = 7'd0;
      end

      S_ERROR: begin
        // Return to IDLE next cycle
        state_nxt = S_IDLE;
        cycle_cnt_nxt = 7'd0;
      end

      default: state_nxt = S_IDLE;
    endcase
  end
endmodule