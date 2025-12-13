module sliding_blocks_check(
  input  [1:0]        init_r,
  input  [1:0]        init_c,
  input  [3:0][1:0]   target_r,
  input  [3:0][1:0]   target_c,
  input  [1:0]        block_count,
  output reg          possible
);

  // Internal wires for enabled targets (0..block_count-1 are valid)
  wire [3:0] en;
  assign en[0] = (block_count > 0);
  assign en[1] = (block_count > 1);
  assign en[2] = (block_count > 2);
  assign en[3] = (block_count > 3);

  // Collect all nodes: node 0 is initial, nodes 1..4 are targets (if enabled)
  // Positions
  wire [1:0] node_r [0:4];
  wire [1:0] node_c [0:4];
  wire       node_valid [0:4];

  assign node_r[0] = init_r;
  assign node_c[0] = init_c;
  assign node_valid[0] = 1'b1;

  genvar gi;
  generate
    for (gi = 0; gi < 4; gi = gi + 1) begin : NODE_ASSIGN
      assign node_r[gi+1] = target_r[gi];
      assign node_c[gi+1] = target_c[gi];
      assign node_valid[gi+1] = en[gi];
    end
  endgenerate

  // ------------------------------------------------------------
  // Helper: check if a grid cell is occupied by any block
  // ------------------------------------------------------------
  function automatic is_occupied;
    input [1:0] rr;
    input [1:0] cc;
    begin
      is_occupied = 1'b0;
      // initial block
      if ((init_r == rr) && (init_c == cc)) is_occupied = 1'b1;
      // targets (only enabled ones)
      if (en[0] && (target_r[0] == rr) && (target_c[0] == cc)) is_occupied = 1'b1;
      if (en[1] && (target_r[1] == rr) && (target_c[1] == cc)) is_occupied = 1'b1;
      if (en[2] && (target_r[2] == rr) && (target_c[2] == cc)) is_occupied = 1'b1;
      if (en[3] && (target_r[3] == rr) && (target_c[3] == cc)) is_occupied = 1'b1;
    end
  endfunction

  // ------------------------------------------------------------
  // Directional sliding from edge: returns 1 if target cell can be
  // reached by sliding from some board edge along a straight line
  // without encountering another block beforehand.
  // Directions: from top (down), bottom (up), left (right), right (left)
  // ------------------------------------------------------------

  function automatic can_reach_from_top;
    input [1:0] tr;
    input [1:0] tc;
    integer r;
    begin
      // Only if somewhere below top row (r>=0 allowed). Start above board at r=-1.
      // Scan from row 0 up to tr-1 in same column
      can_reach_from_top = 1'b1;
      for (r = 0; r < tr; r = r + 1) begin
        if (is_occupied(r[1:0], tc)) begin
          can_reach_from_top = 1'b0;
        end
      end
    end
  endfunction

  function automatic can_reach_from_bottom;
    input [1:0] tr;
    input [1:0] tc;
    integer r;
    begin
      // Scan from row 3 down to tr+1 in same column
      can_reach_from_bottom = 1'b1;
      for (r = 3; r > tr; r = r - 1) begin
        if (is_occupied(r[1:0], tc)) begin
          can_reach_from_bottom = 1'b0;
        end
      end
    end
  endfunction

  function automatic can_reach_from_left;
    input [1:0] tr;
    input [1:0] tc;
    integer c;
    begin
      // Scan from col 0 to tc-1 in same row
      can_reach_from_left = 1'b1;
      for (c = 0; c < tc; c = c + 1) begin
        if (is_occupied(tr, c[1:0])) begin
          can_reach_from_left = 1'b0;
        end
      end
    end
  endfunction

  function automatic can_reach_from_right;
    input [1:0] tr;
    input [1:0] tc;
    integer c;
    begin
      // Scan from col 3 down to tc+1 in same row
      can_reach_from_right = 1'b1;
      for (c = 3; c > tc; c = c - 1) begin
        if (is_occupied(tr, c[1:0])) begin
          can_reach_from_right = 1'b0;
        end
      end
    end
  endfunction

  // ------------------------------------------------------------
  // Edge reachability for each target (from at least one direction)
  // ------------------------------------------------------------
  wire [3:0] target_edge_ok;

  generate
    for (gi = 0; gi < 4; gi = gi + 1) begin : EDGE_CHECK
      wire [1:0] tr = target_r[gi];
      wire [1:0] tc = target_c[gi];
      wire from_top    = can_reach_from_top(tr, tc);
      wire from_bottom = can_reach_from_bottom(tr, tc);
      wire from_left   = can_reach_from_left(tr, tc);
      wire from_right  = can_reach_from_right(tr, tc);
      assign target_edge_ok[gi] = en[gi] ? (from_top | from_bottom | from_left | from_right) : 1'b1;
    end
  endgenerate

  // ------------------------------------------------------------
  // Tree structure check among all blocks (initial + targets)
  // Undirected graph: edge between two blocks if they lie on same
  // row or column with no other block strictly between them.
  // Conditions for tree on N valid nodes:
  //  - No overlapping nodes
  //  - Connected
  //  - Edge_count == N-1  (implies no cycle)
  // ------------------------------------------------------------

  // Overlap check (distinct nodes must not share same coordinates)
  integer i, j;
  reg no_overlap;

  always @* begin
    no_overlap = 1'b1;
    for (i = 0; i < 5; i = i + 1) begin
      if (node_valid[i]) begin
        for (j = i + 1; j < 5; j = j + 1) begin
          if (node_valid[j]) begin
            if ((node_r[i] == node_r[j]) && (node_c[i] == node_c[j])) begin
              no_overlap = 1'b0;
            end
          end
        end
      end
    end
  end

  // Compute adjacency (undirected) based on clear straight line
  reg adj [0:4][0:4];

  always @* begin
    // default
    for (i = 0; i < 5; i = i + 1) begin
      for (j = 0; j < 5; j = j + 1) begin
        adj[i][j] = 1'b0;
      end
    end

    // For each pair of distinct valid nodes, connect if directly visible
    // (same row or same column, with no other valid node strictly between).
    for (i = 0; i < 5; i = i + 1) begin
      if (node_valid[i]) begin
        for (j = i + 1; j < 5; j = j + 1) begin
          if (node_valid[j]) begin
            // Check alignment
            if (node_r[i] == node_r[j]) begin
              // Same row: check intermediate columns
              int cmin, cmax, c;
              cmin = (node_c[i] < node_c[j]) ? node_c[i] : node_c[j];
              cmax = (node_c[i] > node_c[j]) ? node_c[i] : node_c[j];
              reg clear;
              clear = 1'b1;
              for (c = cmin + 1; c < cmax; c = c + 1) begin
                if (is_occupied(node_r[i], c[1:0])) begin
                  clear = 1'b0;
                end
              end
              if (clear) begin
                adj[i][j] = 1'b1;
                adj[j][i] = 1'b1;
              end
            end
            else if (node_c[i] == node_c[j]) begin
              // Same column: check intermediate rows
              int rmin, rmax, r2;
              rmin = (node_r[i] < node_r[j]) ? node_r[i] : node_r[j];
              rmax = (node_r[i] > node_r[j]) ? node_r[i] : node_r[j];
              reg clear2;
              clear2 = 1'b1;
              for (r2 = rmin + 1; r2 < rmax; r2 = r2 + 1) begin
                if (is_occupied(r2[1:0], node_c[i])) begin
                  clear2 = 1'b0;
                end
              end
              if (clear2) begin
                adj[i][j] = 1'b1;
                adj[j][i] = 1'b1;
              end
            end
          end
        end
      end
    end
  end

  // Count valid nodes
  reg [2:0] node_cnt;
  always @* begin
    node_cnt = 3'd0;
    for (i = 0; i < 5; i = i + 1) begin
      if (node_valid[i]) node_cnt = node_cnt + 3'd1;
    end
  end

  // Count edges (undirected, i<j)
  reg [3:0] edge_cnt;
  always @* begin
    edge_cnt = 4'd0;
    for (i = 0; i < 5; i = i + 1) begin
      for (j = i + 1; j < 5; j = j + 1) begin
        if (adj[i][j]) edge_cnt = edge_cnt + 4'd1;
      end
    end
  end

  // Connectivity via simple combinational reachability (small fixed N=5)
  reg visited [0:4];

  task automatic mark_reachable;
    integer x, y;
    begin
      // Start from node 0 (initial), if valid
      for (x = 0; x < 5; x = x + 1) begin
        visited[x] = 1'b0;
      end
      if (!node_valid[0]) begin
        // If somehow initial invalid (should not), leave all 0
      end else begin
        visited[0] = 1'b1;
        // Propagate up to 4 iterations (enough for 5 nodes)
        repeat (4) begin
          for (x = 0; x < 5; x = x + 1) begin
            if (visited[x]) begin
              for (y = 0; y < 5; y = y + 1) begin
                if (node_valid[y] && adj[x][y]) begin
                  visited[y] = 1'b1;
                end
              end
            end
          end
        end
      end
    end
  endtask

  reg all_connected;
  always @* begin
    mark_reachable();
    all_connected = 1'b1;
    for (i = 0; i < 5; i = i + 1) begin
      if (node_valid[i] && !visited[i]) begin
        all_connected = 1'b0;
      end
    end
  end

  // Tree check conditions
  wire tree_ok;
  assign tree_ok = no_overlap && all_connected && (edge_cnt == (node_cnt - 1));

  // All targets must have valid edge sliding path
  wire targets_ok;
  assign targets_ok = target_edge_ok[0] & target_edge_ok[1] & target_edge_ok[2] & target_edge_ok[3];

  // Final possible flag
  always @* begin
    possible = tree_ok && targets_ok;
  end

endmodule
