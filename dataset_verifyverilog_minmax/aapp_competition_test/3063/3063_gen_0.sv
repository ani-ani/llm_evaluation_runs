module debt_resolution (
  input [7:0] valid_mask,
  input [2:0] a_id [7:0],
  input [13:0] b_amount [7:0],
  output reg [16:0] total_min
);

  // Helper: index existence from bitmask
  function bit is_valid(input int idx);
    is_valid = valid_mask[idx];
  endfunction

  // Johnson-style DFS restricted to simple cycles with lexicographic pruning.
  // Cycles are then canonicalized and deduplicated; total_min is sum of min edge per unique cycle.

  // Path state
  logic [2:0] path [8];
  logic visited [8];
  int path_len;
  int start_id;
  int min_start_id;
  bit closed_already;

  // Unique cycle storage (max 8 nodes => at most 40320 simple cycles, but in practice far fewer)
  logic [7:0] unique_starts [64];
  logic [7:0] unique_dirs [64];
  int unique_count;
  int unique_min [64];

  // Cycle detection state
  logic [2:0] cur_cycle [8];
  int cur_cycle_len;
  int cur_min_amount;

  // Generate adjacency list once (packed; -1 means no edge)
  int adj_next [8]; // next node index for each node, or -1 if none
  int adj_edge_idx [8]; // edge index for b_amount lookup (i-th valid person = i)
  int adj_size;

  // Canonical rotation selection
  function [2:0] rotate_dir(
    input logic [2:0] cyc [8],
    input int len,
    input int start_i,  // index in cyc[0:len-1] to start from
    input int dir       // 0: forward, 1: backward
  );
    int k, p;
    if (dir == 0) begin
      // Forward: s, s+1, ..., len-1, 0, ..., s-1
      rotate_dir = cyc[start_i];
    end else begin
      // Backward: s, s-1, ..., 0, len-1, ..., s+1
      k = start_i;
      p = (k - 1 + len) % len; // previous index
      rotate_dir = cyc[p];
    end
  endfunction

  // Choose lexicographically smaller rotation among forward and backward canonical rotations
  function void choose_canonical(
    input logic [2:0] cyc [8],
    input int len,
    output int chosen_start,
    output int chosen_dir
  );
    int i;
    logic [2:0] f0, b0;
    logic [15:0] sum_f, sum_b;
    int diff;

    // Forward canonical rotation index
    i = 0;
    f0 = cyc[0];
    for (int k = 1; k < len; k++) begin
      if (cyc[k] < f0) begin
        f0 = cyc[k];
        i = k;
      end
    end

    // Backward canonical rotation index
    b0 = cyc[0];
    for (int k = 1; k < len; k++) begin
      logic [2:0] t = cyc[(len - k) % len];
      if (t < b0) begin
        b0 = t;
        i = k; // reuse 'i' as temp here; restore below
      end
    end

    // Evaluate which canonical rotation is smaller lexicographically
    // Compare forward vs backward sequences starting at their canonical starts
    sum_f = 0; sum_b = 0;
    for (int k = 0; k < len; k++) begin
      sum_f += 16'(cyc[(i + k) % len]);
      sum_b += 16'(cyc[(i - k + len) % len]);
    end

    diff = 16'(sum_f) - 16'(sum_b);
    if (diff < 0) begin
      chosen_start = 0; // we will not use these directly; will be passed via f0/b0
      chosen_dir = 0;
    end else if (diff > 0) begin
      chosen_start = 0;
      chosen_dir = 1;
    end else begin
      // equal sums: choose the one with smaller starting node value
      if (8'(f0) <= 8'(b0)) begin
        chosen_start = 0;
        chosen_dir = 0;
      end else begin
        chosen_start = 0;
        chosen_dir = 1;
      end
    end
  endfunction

  // Compare two canonical representatives (start node, dir) and a numeric key (sum)
  function bit same_canonical(
    input int s1, dir1, key1,
    input int s2, dir2, key2
  );
    same_canonical = (s1 == s2) && (dir1 == dir2) && (key1 == key2);
  endfunction

  // Add a detected cycle to unique list if not already present (using canonical repr + sum key)
  function void add_cycle_if_unique(
    input logic [2:0] cyc [8],
    input int len,
    input int cyc_min
  );
    int canon_s, canon_d;
    logic [2:0] start_node;
    logic [15:0] key_sum;
    int s_c, d_c;
    // Determine forward and backward canonical start nodes
    begin
      logic [2:0] f0, b0;
      int i_f, i_b;
      f0 = cyc[0]; i_f = 0;
      for (int k = 1; k < len; k++) begin
        if (cyc[k] < f0) begin f0 = cyc[k]; i_f = k; end
      end
      b0 = cyc[0]; i_b = 0;
      for (int k = 1; k < len; k++) begin
        logic [2:0] t = cyc[(len - k) % len];
        if (t < b0) begin b0 = t; i_b = k; end
      end
      // Compare canonical rotations lexicographically
      logic [15:0] sum_f = 0, sum_b = 0;
      for (int k = 0; k < len; k++) begin
        sum_f += 16'(cyc[(i_f + k) % len]);
        sum_b += 16'(cyc[(i_b - k + len) % len]);
      end
      if (16'(sum_f) < 16'(sum_b)) begin
        canon_s = 8'(f0);
        canon_d = 0;
      end else if (16'(sum_f) > 16'(sum_b)) begin
        canon_s = 8'(b0);
        canon_d = 1;
      end else begin
        if (8'(f0) <= 8'(b0)) begin
          canon_s = 8'(f0);
          canon_d = 0;
        end else begin
          canon_s = 8'(b0);
          canon_d = 1;
        end
      end
      key_sum = sum_f; // same as sum_b when equal
    end

    // Deduplicate by canonical start, direction, and sum key
    for (int i = 0; i < unique_count; i++) begin
      if (same_canonical(canon_s, canon_d, 16'(key_sum),
                         unique_starts[i], unique_dirs[i], unique_min[i])) begin
        return; // already present
      end
    end
    // New unique cycle
    if (unique_count < 64) begin
      unique_starts[unique_count] = canon_s;
      unique_dirs[unique_count] = canon_d;
      unique_min[unique_count] = cyc_min;
      unique_count++;
    end
  endfunction

  // Detect cycles starting at node 's' using DFS
  task dfs_find(input int s);
    visited[s] = 1'b1;
    path[path_len] = s;
    path_len++;

    // The first edge in the path is at index 0 (path[0] = s)
    // Each subsequent extension adds one edge (path[k-1] -> path[k])
    // To prevent duplicates, enforce lexicographic order: all internal nodes > start node
    // Close cycle only when encountering the start node from the last path node
    for (int v = 0; v < 8; v++) begin
      if (!is_valid(v) || !is_valid(path[path_len-1])) continue;
      // Edge check: does path[path_len-1] have an edge to v?
      if (adj_next[path[path_len-1]] != v) continue;

      // Closing back to start?
      if (v == s) begin
        if (path_len >= 2) begin
          // Build cycle nodes in order: s -> ... -> s
          // The sequence path[0:path_len-1] is s, ..., last; v == s closes the cycle
          cur_cycle_len = path_len; // number of distinct nodes in the cycle
          for (int k = 0; k < cur_cycle_len; k++) begin
            cur_cycle[k] = path[k];
          end
          // Compute min edge in this cycle: edges are from cur_cycle[i] -> cur_cycle[(i+1)%len]
          cur_min_amount = b_amount[adj_edge_idx[cur_cycle[0]]];
          for (int i = 1; i < cur_cycle_len; i++) begin
            int eidx = adj_edge_idx[cur_cycle[i]];
            if (b_amount[eidx] < cur_min_amount) cur_min_amount = b_amount[eidx];
          end
          add_cycle_if_unique(cur_cycle, cur_cycle_len, cur_min_amount);
        end
        continue; // do not traverse through the start node again
      end

      // Avoid revisiting nodes within this path (simple cycles only)
      bit in_path = 1'b0;
      for (int k = 0; k < path_len; k++) begin
        if (path[k] == v) begin in_path = 1'b1; end
      end
      if (in_path) continue;

      // Lexicographic pruning: all internal nodes must have ID > start node
      if (v < start_id) continue;

      // Recurse
      dfs_find(v);
    end

    // Backtrack
    path_len--;
    visited[s] = 1'b0;
  endtask

  always_comb begin
    // Build adjacency (each valid person has at most one outgoing edge)
    for (int i = 0; i < 8; i++) begin
      adj_next[i] = -1;
      adj_edge_idx[i] = -1;
    end
    adj_size = 0;
    for (int i = 0; i < 8; i++) begin
      if (valid_mask[i]) begin
        adj_next[i] = a_id[i];
        adj_edge_idx[i] = i; // b_amount indexed by source node i
        adj_size++;
      end
    end

    // Clear unique cycle storage
    unique_count = 0;
    for (int i = 0; i < 64; i++) begin
      unique_starts[i] = 0;
      unique_dirs[i] = 0;
      unique_min[i] = 0;
    end

    // Reset DFS state
    for (int i = 0; i < 8; i++) begin
      visited[i] = 1'b0;
      path[i] = 0;
      cur_cycle[i] = 0;
    end
    path_len = 0;
    cur_cycle_len = 0;
    cur_min_amount = 0;

    // Enumerate simple cycles starting from each valid node (s)
    for (int s = 0; s < 8; s++) begin
      if (!is_valid(s)) continue;
      start_id = s;
      min_start_id = s;
      closed_already = 1'b0;
      dfs_find(s);
    end

    // Sum minimums of unique cycles
    total_min = 17'(0);
    for (int i = 0; i < unique_count; i++) begin
      total_min = total_min + 17'(unique_min[i]);
    end
  end

endmodule