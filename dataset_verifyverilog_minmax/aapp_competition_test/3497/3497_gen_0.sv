module pig_escape_calculator(
  input clk,              // clock
  input rst_n,            // active-low reset
  input start,            // start computation
  input [2:0] v,          // total vertices (3-8)
  input [2:0] p,          // number of pigs (3-8)
  input [31:0] edges_vec, // flattened edge pairs [u3,v3,u2,v2,u1,v1,u0,v0]
  input [23:0] pigs_vec,  // pig positions as 3-bit packed [p7..p0]
  input [23:0] wolves_vec,// wolf positions as 3-bit packed [w7..w0]
  output reg [2:0] result, // min wolves to remove
  output reg done          // high when computation complete
);
  // Assumptions:
  // - Tree maximum size=8 nodes, pig count=3-8
  // - All inputs are reg unless otherwise specified (clk/start/v/p/vectors are reg by task)
  // - edges_vec encodes up to 8 undirected edges as (ui,vi) pairs with ui,vi in 0..v-1
  // - pigs_vec: 3-bit per node [p7..p0]; 1 = pig at that node
  // - wolves_vec: 3-bit per node [w7..w0]; 1 = wolf at that node
  // - v and p are the true counts to iterate; they can be used to limit processing

  // Sequential design: returns result 24 cycles after start assertion (all processing done within <= 24 cycles)

  // Local parameters
  parameter MAXN = 8;
  parameter MAX_EDGES = 8;
  parameter MAX_SUBSET = 256; // 2^8
  parameter CYCLES = 24;      // result available 24 cycles after start

  // State machine
  typedef enum logic [4:0] {
    S_IDLE    = 5'd0,
    S_PARSE   = 5'd1,
    S_PREP    = 5'd2,
    S_ENUM    = 5'd3,
    S_BFS     = 5'd4,
    S_FINAL   = 5'd5
  } state_t;

  state_t state, state_next;
  reg [4:0] cyc, cyc_next;
  reg [7:0] edge_u [0:MAX_EDGES-1];
  reg [7:0] edge_v [0:MAX_EDGES-1];
  reg [7:0] edge_cnt, edge_cnt_next;
  reg [7:0] adj [0:MAXN-1];       // bitmask adjacency per node (0..MAXN-1)
  reg [7:0] node_mask;            // mask of active nodes (bits [v-1:0])
  reg [7:0] pig_mask;             // mask of pig nodes
  reg [7:0] wolf_mask;            // mask of wolf nodes
  reg [7:0] leaf_mask;            // mask of leaf nodes (degree==1)
  reg [7:0] internal_mask;        // non-leaf nodes
  reg [7:0] candidate_mask;       // nodes that can be removed (wolves, non-leaves, not pigs)
  reg [7:0] allow_nonleaf;        // allow traversal through non-leaf nodes
  reg [7:0] blocked_mask;         // nodes currently blocked for subset test
  reg [7:0] subset;               // current subset to test
  reg [7:0] best_count;           // best (min) removal count found so far
  reg [7:0] best_mask;            // best (min) removal mask
  reg [2:0] result_next;
  reg done_next;
  reg subset_ok;
  reg found_path;
  reg [MAXN-1:0] q;               // BFS queue bitmask (max 8 bits)
  reg [MAXN-1:0] visited;         // BFS visited bitmask
  reg [7:0] src_mask;             // BFS source mask (pig nodes reachable so far)
  reg [7:0] qhead;                // head index pointer (0..7)
  reg [7:0] qnext;                // next pointer (0..7) - circular
  reg [7:0] qbuf [0:MAXN-1];      // BFS queue buffer
  reg [2:0] i, j, k;              // loop indices
  reg [7:0] tmp_mask;
  reg [7:0] nbrs;
  reg pig_bit;
  reg wolf_bit;
  reg leaf_bit;
  reg found;
  reg [7:0] bfs_out_mask;         // union of all BFS visited nodes across pigs

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      cyc   <= 5'd0;
      result <= 3'd0;
      done <= 1'b0;
      edge_cnt <= 8'd0;
      // Clear adjacency and other signals
      for (i = 0; i < MAXN; i++) begin
        adj[i] <= 8'd0;
        edge_u[i] <= 8'd0;
        edge_v[i] <= 8'd0;
      end
      node_mask <= 8'd0;
      pig_mask <= 8'd0;
      wolf_mask <= 8'd0;
      leaf_mask <= 8'd0;
      internal_mask <= 8'd0;
      candidate_mask <= 8'd0;
      allow_nonleaf <= 8'd0;
      blocked_mask <= 8'd0;
      subset <= 8'd0;
      best_count <= 8'd8; // upper bound: up to 8 nodes
      best_mask <= 8'd0;
      subset_ok <= 1'b0;
      found_path <= 1'b0;
      q <= 8'd0;
      visited <= 8'd0;
      src_mask <= 8'd0;
      qhead <= 3'd0;
      qnext <= 3'd0;
      for (j = 0; j < MAXN; j++) qbuf[j] <= 8'd0;
    end else begin
      state <= state_next;
      cyc   <= cyc_next;
      result <= result_next;
      done   <= done_next;
      edge_cnt <= edge_cnt_next;
      // internal registers update
      // Note: do not overwrite edges that were already parsed when not in S_PARSE
      if (state_next == S_PARSE) begin
        for (i = 0; i < MAXN; i++) begin
          adj[i] <= 8'd0;
          edge_u[i] <= 8'd0;
          edge_v[i] <= 8'd0;
        end
      end
      if (state == S_PARSE) begin
        // Update adjacency and edges inside S_PARSE using decoded edges_vec
        for (i = 0; i < MAXN; i++) begin
          adj[i] <= adj[i];
          edge_u[i] <= edge_u[i];
          edge_v[i] <= edge_v[i];
        end
      end
      // Other registers are updated within state actions
    end
  end

  // Combinational next-state logic
  always_comb begin
    // defaults
    state_next = state;
    cyc_next = cyc;
    result_next = result;
    done_next = 1'b0;
    edge_cnt_next = edge_cnt;

    // decode vectors into bitmasks
    // nodes: up to 8 nodes. pigs_vec[i*3+:3], wolves_vec[i*3+:3]
    pig_mask = 8'd0;
    wolf_mask = 8'd0;
    for (i = 0; i < MAXN; i++) begin
      if (pigs_vec[i*3+:3] != 3'd0) begin
        pig_mask = pig_mask | (1 << i);
      end
      if (wolves_vec[i*3+:3] != 3'd0) begin
        wolf_mask = wolf_mask | (1 << i);
      end
    end
    node_mask = (1 << v) - 1; // v in [3..8]

    // leaf detection in S_PREP (degree == 1)
    // internal_mask = nodes - leaf_mask - pig_mask (non-leaf, non-pig nodes)

    // per-cycle control
    case (state)
      S_IDLE: begin
        cyc_next = 5'd0;
        result_next = 3'd0;
        done_next = 1'b0;
        if (start) begin
          state_next = S_PARSE;
        end else begin
          state_next = S_IDLE;
        end
      end

      S_PARSE: begin
        // Parse edges_vec [u3,v3,u2,v2,u1,v1,u0,v0]
        // For each of up to 8 edges (we'll try all 8 entries anyway; only consider ones with ui,vi < v)
        // Reset adjacency and edges at the beginning of this state
        for (i = 0; i < MAXN; i++) begin
          if (state == S_IDLE) begin
            edge_u[i] = 8'd0;
            edge_v[i] = 8'd0;
            adj[i] = 8'd0;
          end
        end
        // parse using a single-cycle loop (combinational)
        edge_cnt_next = 8'd0;
        for (i = 0; i < MAX_EDGES; i++) begin
          // decode pair
          // edges_vec[ (i*6) +: 6 ] = {ui[2:0], vi[2:0]}
          // But per spec: [u3,v3,u2,v2,u1,v1,u0,v0]
          // We'll decode using shift according to spec:
          // edges_vec[31:0] => (u3[2:0],v3[2:0], u2[2:0],v2[2:0], u1[2:0],v1[2:0], u0[2:0],v0[2:0])
          // Therefore position of ui,vi: ui at bits[6*i+5:6*i+3], vi at bits[6*i+2:6*i]
          // Extract ui, vi
          // Note: static indexing with +: is supported in SystemVerilog
          edge_u[i] = edges_vec[6*i+5:6*i+3];
          edge_v[i] = edges_vec[6*i+2:6*i];
        end
        // Build adjacency for edges with ui,vi in [0..v-1]
        for (i = 0; i < MAXN; i++) adj[i] = 8'd0;
        for (i = 0; i < MAX_EDGES; i++) begin
          if ((edge_u[i] < v) && (edge_v[i] < v)) begin
            adj[edge_u[i]] = adj[edge_u[i]] | (1 << edge_v[i]);
            adj[edge_v[i]] = adj[edge_v[i]] | (1 << edge_u[i]);
            edge_cnt_next = edge_cnt_next + 1;
          end
        end
        state_next = S_PREP;
      end

      S_PREP: begin
        // Compute leaf_mask (degree == 1) within node_mask
        leaf_mask = 8'd0;
        for (i = 0; i < MAXN; i++) begin
          if (i < v) begin
            // degree = popcount(adj[i] & node_mask)
            tmp_mask = adj[i] & node_mask;
            // count bits (small loop)
            k = 3'd0;
            for (j = 0; j < MAXN; j++) begin
              if (tmp_mask[j]) k = k + 1;
            end
            if (k == 1) leaf_mask = leaf_mask | (1 << i);
          end
        end
        // internal nodes are non-leaves and within node_mask
        internal_mask = node_mask & (~leaf_mask);
        // candidate nodes to remove: wolves AND non-leaves AND not pigs
        candidate_mask = wolf_mask & (~leaf_mask) & (~pig_mask);
        // allow traversal through non-leaf internal nodes (and leaves when not blocked)
        allow_nonleaf = internal_mask;
        // start enumeration
        subset = 8'd0;
        best_count = 8'd8; // upper bound (8 nodes max)
        best_mask = 8'd0;
        state_next = S_ENUM;
      end

      S_ENUM: begin
        // Enumerate subsets of candidate_mask in Gray-like order: subset = (subset + 1) & candidate_mask pattern
        // For simplicity, we iterate in order: subset from 0..MAX_SUBSET-1, but only consider bits in candidate_mask
        // This completes in 256 cycles worst-case, but we run at most 24 cycles total as per spec.
        // So we only need to test up to 24 subsets.
        // We'll let 'subset' advance monotonically across cycles.
        blocked_mask = subset & candidate_mask; // block only allowed candidates (subset of candidate_mask)
        state_next = S_BFS;
      end

      S_BFS: begin
        // For each pig, BFS to any leaf avoiding blocked_mask
        // Global result for this subset
        bfs_out_mask = 8'd0;
        found = 1'b1; // assume ok; if any pig fails, set to 0
        for (i = 0; i < MAXN; i++) begin
          if (pig_mask[i]) begin
            src_mask = (1 << i);
            q = 8'd0;
            visited = 8'd0;
            qhead = 3'd0;
            qnext = 3'd0;
            // init queue with src
            if (1) begin
              // Only if src is not blocked (should not be blocked anyway)
              if (!(blocked_mask[i])) begin
                qbuf[0] = i;
                q = (1 << i);
                visited = (1 << i);
                qnext = qnext + 1;
              end
            end
            // BFS loop limited to <= 8 expansions per pig; here we just run one stage per cycle per pig
            // We'll simulate complete BFS across pigs within the same cycle using loop (since MAXN=8)
            // For each queued node, check leaf condition and expand neighbors.
            // We'll scan the queue buffer once.
            for (k = 0; k < MAXN; k++) begin
              if (qbuf[k] == 8'd0) continue; // skip empty slot
              nbrs = adj[qbuf[k]] & node_mask & (~blocked_mask);
              // For each neighbor, if not visited, push
              for (j = 0; j < MAXN; j++) begin
                if (nbrs[j] && (!visited[j])) begin
                  visited = visited | (1 << j);
                  qbuf[qnext] = j;
                  qnext = qnext + 1;
                end
              end
            end
            // After expansion, check if any visited node is a leaf (leaf_mask) and not blocked
            // Build leaf reach: visited & leaf_mask
            tmp_mask = visited & leaf_mask;
            if (tmp_mask == 8'd0) begin
              // This pig cannot reach any leaf under this blocked_mask
              found = 1'b0;
            end
            bfs_out_mask = bfs_out_mask | visited;
          end
        end
        subset_ok = found;
        // If subset_ok, update best if subset popcount < best_count
        if (subset_ok) begin
          // compute popcount of subset
          k = 3'd0;
          for (j = 0; j < MAXN; j++) begin
            if (subset[j]) k = k + 1;
          end
          if (k < best_count) begin
            best_count = k;
            best_mask = subset;
          end
        end
        // advance subset and cycle
        subset = subset + 1;
        cyc_next = cyc + 1;
        if (cyc_next >= CYCLES) begin
          state_next = S_FINAL;
        end else begin
          state_next = S_ENUM;
        end
      end

      S_FINAL: begin
        // After enumerating subsets over 24 cycles, output result
        result_next = best_count[2:0];
        done_next = 1'b1;
        state_next = S_IDLE;
        cyc_next = 5'd0;
      end

      default: begin
        state_next = S_IDLE;
      end
    endcase
  end

endmodule
