module escape_network(
  input clk, // system clock
  input rst_n, // active-low reset
  input start, // starts computation when high
  input [2:0] n, // number of nodes (2-8)
  input [2:0] h, // headquarters node ID
  input [41:0] edges, // 7 edges packed as [a0,b0,a1,b1,...,a6,b6] (each 3 bits)
  output reg [2:0] m, // number of edges to add (0-7)
  output reg [41:0] added_edges, // result edges (same packing as input)
  output reg done // high when results valid
);

  // Parameters
  parameter MAX_N = 8;
  parameter MAX_E = 7;
  parameter STATE_W = 3;
  parameter IDLE = 3'd0;
  parameter PARSE_EDGES = 3'd1;
  parameter DFS_TRAVERSE = 3'd2;
  parameter BRIDGE_DETECT = 3'd3;
  parameter CONNECT_COMPONENTS = 3'd4;

  // Internal signals
  reg [STATE_W-1:0] state, next_state;
  reg [2:0] n_r, h_r;
  reg [41:0] edges_r;

  // Adjacency (fixed size 8 nodes)
  reg [2:0] adj_u [0:MAX_N-1][0:MAX_E-1];
  reg [2:0] adj_v [0:MAX_N-1][0:MAX_E-1];
  reg [2:0] adj_deg [0:MAX_N-1];

  // DFS state
  reg [2:0] dfs_stack [0:MAX_N-1];
  reg [2:0] dfs_sp; // stack pointer (points to next free slot)
  reg [2:0] cur_node;
  reg [2:0] cur_edge_idx; // next edge to explore from cur_node
  reg [2:0] parent_node [0:MAX_N-1];
  reg [2:0] parent_edge [0:MAX_N-1];
  reg visited [0:MAX_N-1];
  reg disc [0:MAX_N-1]; // discovery time
  reg [3:0] dfs_time; // time counter
  reg [2:0] num_nodes;

  // Bridges
  reg is_bridge [0:MAX_E-1]; // 1 if edge index i is a bridge
  reg [2:0] bridge_u [0:MAX_E-1]; // oriented bridge endpoints (parent->child)
  reg [2:0] bridge_v [0:MAX_E-1];
  reg [2:0] bridge_cnt;

  // Bridge-tree components (each original node assigned to a component)
  reg [2:0] comp_id [0:MAX_N-1];
  reg [2:0] comp_of_edge [0:MAX_E-1];
  reg [2:0] comp_deg [0:MAX_N-1];
  reg [2:0] comp_u [0:MAX_N-1][0:MAX_E-1]; // bridge-tree adjacency (component graph)
  reg [2:0] comp_v [0:MAX_N-1][0:MAX_E-1];
  reg [2:0] comp_adj_deg [0:MAX_N-1];
  reg [2:0] comp_cnt;

  // Leaves in bridge-tree
  reg [2:0] leaves [0:MAX_N-1]; // component ids that are leaves
  reg [2:0] leaf_cnt;
  reg [2:0] leaf_head; // head pointer
  reg [2:0] leaf_tail; // tail pointer
  reg [2:0] leaf_buf [0:MAX_N-1]; // circular buffer

  // Added edges accumulation
  reg [5:0] add_u [0:MAX_E-1]; // 3-bit each, use 6 to allow 0..7 storage
  reg [5:0] add_v [0:MAX_E-1];
  reg [2:0] add_ptr;
  reg [2:0] out_idx;
  reg [2:0] pair_first; // temporary to hold first leaf of a pair
  reg [2:0] bfs_q [0:MAX_N-1]; // BFS queue for shortest path
  reg [2:0] bfs_head, bfs_tail;
  reg bfs_vis [0:MAX_N-1];
  reg [2:0] prev_node [0:MAX_N-1];
  reg [2:0] prev_edge [0:MAX_N-1];
  reg [2:0] path_len;

  // Utility functions
  function [5:0] edge_key;
    input [2:0] a, b;
    reg [5:0] e1, e2;
  begin
    if (a < b) begin
      e1 = {3'b0, a};
      e2 = {3'b0, b};
    end else begin
      e1 = {3'b0, b};
      e2 = {3'b0, a};
    end
    edge_key = {e1, e2}; // 6+6 = 12 bits (not directly used, but canonical order)
  end
  endfunction

  function eq_edge;
    input [2:0] a1, b1, a2, b2;
    reg [5:0] e1, e2;
  begin
    if (a1 < b1) e1 = {3'b0, a1, 3'b0, b1}; else e1 = {3'b0, b1, 3'b0, a1};
    if (a2 < b2) e2 = {3'b0, a2, 3'b0, b2}; else e2 = {3'b0, b2, 3'b0, a2};
    eq_edge = (e1 == e2);
  end
  endfunction

  // Reset and clocking
  integer i, j;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      m <= 3'd0;
      added_edges <= 42'd0;
      done <= 1'b0;
      // Clear adjacency and degrees
      for (i = 0; i < MAX_N; i = i + 1) begin
        adj_deg[i] <= 3'd0;
        for (j = 0; j < MAX_E; j = j + 1) begin
          adj_u[i][j] <= 3'd0;
          adj_v[i][j] <= 3'd0;
        end
      end
      // Clear DFS internals
      dfs_sp <= 3'd0;
      for (i = 0; i < MAX_N; i = i + 1) begin
        visited[i] <= 1'b0;
        disc[i] <= 3'd0;
        parent_node[i] <= 3'd0;
        parent_edge[i] <= 3'd0;
      end
      cur_node <= 3'd0;
      cur_edge_idx <= 3'd0;
      dfs_time <= 4'd0;
      bridge_cnt <= 3'd0;
      for (i = 0; i < MAX_E; i = i + 1) begin
        is_bridge[i] <= 1'b0;
        bridge_u[i] <= 3'd0;
        bridge_v[i] <= 3'd0;
      end
      // Bridge-tree storage
      for (i = 0; i < MAX_N; i = i + 1) begin
        comp_id[i] <= 3'd0;
        comp_deg[i] <= 3'd0;
        comp_adj_deg[i] <= 3'd0;
        for (j = 0; j < MAX_E; j = j + 1) begin
          comp_u[i][j] <= 3'd0;
          comp_v[i][j] <= 3'd0;
        end
      end
      comp_cnt <= 3'd0;
      leaf_cnt <= 3'd0;
      leaf_head <= 3'd0;
      leaf_tail <= 3'd0;
      for (i = 0; i < MAX_N; i = i + 1) leaves[i] <= 3'd0;
      for (i = 0; i < MAX_N; i = i + 1) leaf_buf[i] <= 3'd0;
      add_ptr <= 3'd0;
      out_idx <= 3'd0;
      pair_first <= 3'd0;
      bfs_head <= 3'd0; bfs_tail <= 3'd0;
      for (i = 0; i < MAX_N; i = i + 1) begin
        bfs_vis[i] <= 1'b0;
        prev_node[i] <= 3'd0;
        prev_edge[i] <= 3'd0;
        bfs_q[i] <= 3'd0;
      end
      path_len <= 3'd0;
      n_r <= 3'd0; h_r <= 3'd0; edges_r <= 42'd0;
    end else begin
      // Default: hold outputs unless state changes dictate
      // State machine
      case (state)
        IDLE: begin
          done <= 1'b0;
          m <= 3'd0;
          added_edges <= 42'd0;
          if (start) begin
            // Latch inputs
            n_r <= n;
            h_r <= h;
            edges_r <= edges;
            // Reset working structures
            for (i = 0; i < MAX_N; i = i + 1) begin
              adj_deg[i] <= 3'd0;
              visited[i] <= 1'b0;
              disc[i] <= 3'd0;
              parent_node[i] <= 3'd0;
              parent_edge[i] <= 3'd0;
              comp_deg[i] <= 3'd0;
              comp_adj_deg[i] <= 3'd0;
              comp_id[i] <= 3'd0;
              bfs_vis[i] <= 1'b0;
              prev_node[i] <= 3'd0;
              prev_edge[i] <= 3'd0;
            end
            for (i = 0; i < MAX_E; i = i + 1) begin
              is_bridge[i] <= 1'b0;
              bridge_u[i] <= 3'd0;
              bridge_v[i] <= 3'd0;
              comp_of_edge[i] <= 3'd0;
            end
            bridge_cnt <= 3'd0;
            comp_cnt <= 3'd0;
            leaf_cnt <= 3'd0;
            leaf_head <= 3'd0;
            leaf_tail <= 3'd0;
            for (i = 0; i < MAX_N; i = i + 1) begin
              leaves[i] <= 3'd0;
              leaf_buf[i] <= 3'd0;
            end
            for (i = 0; i < MAX_E; i = i + 1) begin
              add_u[i] <= 6'd0;
              add_v[i] <= 6'd0;
            end
            add_ptr <= 3'd0;
            out_idx <= 3'd0;
            pair_first <= 3'd0;
            bfs_head <= 3'd0; bfs_tail <= 3'd0;
            path_len <= 3'd0;
            // Initialize DFS at headquarters (or node 0 if h is out of range)
            if (h < n) cur_node <= h;
            else cur_node <= 3'd0;
            cur_edge_idx <= 3'd0;
            dfs_sp <= 3'd1;
            dfs_stack[0] <= (h < n) ? h : 3'd0;
            visited[(h < n) ? h : 3'd0] <= 1'b1;
            disc[(h < n) ? h : 3'd0] <= 4'd0;
            dfs_time <= 4'd1;
            num_nodes <= n;
            state <= PARSE_EDGES;
          end
        end

        PARSE_EDGES: begin
          // Build undirected adjacency from edges_r for exactly (n_r-1) edges
          // Process one edge per cycle for up to 7 cycles
          if (out_idx < (n_r - 3'd1)) begin
            // Extract pair out_idx from packed 42-bit (a:3b, b:3b)
            // Each pair is 6 bits: bits [5:3]=a, bits [2:0]=b
            // Pair i: bits [6*i+5 : 6*i]
            // Compute indices
            // a: (edges_r >> (6*out_idx + 5)) & 3'b111
            // b: (edges_r >> (6*out_idx + 0)) & 3'b111
            reg [2:0] a, b;
            a = edges_r[(6*out_idx + 5) -: 3];
            b = edges_r[(6*out_idx + 0) -: 3];
            // Add to adj list of a and b if within range
            if (a < n_r && b < n_r) begin
              // a -> b
              i = adj_deg[a];
              if (i < MAX_E) begin
                adj_u[a][i] <= a;
                adj_v[a][i] <= b;
                adj_deg[a] <= adj_deg[a] + 3'd1;
              end
              // b -> a
              i = adj_deg[b];
              if (i < MAX_E) begin
                adj_u[b][i] <= b;
                adj_v[b][i] <= a;
                adj_deg[b] <= adj_deg[b] + 3'd1;
              end
            end
            out_idx <= out_idx + 3'd1;
          end else begin
            // Done parsing
            out_idx <= 3'd0;
            state <= DFS_TRAVERSE;
          end
        end

        DFS_TRAVERSE: begin
          if (dfs_sp == 3'd0) begin
            // DFS complete
            state <= BRIDGE_DETECT;
          end else begin
            // Look at top of stack
            cur_node <= dfs_stack[dfs_sp - 1];
            // If finished all edges for this node, pop
            if (cur_edge_idx >= adj_deg[cur_node]) begin
              dfs_sp <= dfs_sp - 3'd1;
              cur_edge_idx <= 3'd0;
            end else begin
              // Explore next edge
              if (cur_edge_idx < adj_deg[cur_node]) begin
                reg [2:0] v;
                v = adj_v[cur_node][cur_edge_idx];
                // Move cur_edge_idx forward for next cycle
                cur_edge_idx <= cur_edge_idx + 3'd1;
                if (!visited[v]) begin
                  // Tree edge: push child
                  visited[v] <= 1'b1;
                  parent_node[v] <= cur_node;
                  parent_edge[v] <= cur_edge_idx - 3'd1; // the edge index we just used
                  disc[v] <= dfs_time;
                  dfs_time <= dfs_time + 4'd1;
                  dfs_sp <= dfs_sp + 3'd1;
                  dfs_stack[dfs_sp] <= v;
                end else begin
                  // Back edge: check bridge condition
                  // If v is ancestor (disc[v] < disc[cur_node]), and edge index < parent edge, it's a bridge
                  if (disc[v] < disc[cur_node]) begin
                    if (cur_edge_idx - 3'd1 != parent_edge[cur_node]) begin
                      // Mark as bridge (use oriented endpoints parent->child)
                      bridge_u[bridge_cnt] <= cur_node;
                      bridge_v[bridge_cnt] <= v;
                      is_bridge[cur_edge_idx - 3'd1] <= 1'b1;
                      bridge_cnt <= bridge_cnt + 3'd1;
                    end
                  end
                  // else: forward/cross edge in undirected graph; ignore
                end
              end
            end
          end
        end

        BRIDGE_DETECT: begin
          // Step 1: Assign component ids via DFS avoiding bridges
          // Use bfs_head/tail for a tiny queue to traverse non-bridge edges
          if (comp_cnt == 3'd0) begin
            // Start from 0, mark as unassigned nodes
            for (i = 0; i < MAX_N; i = i + 1) begin
              if (i < n_r) comp_id[i] <= 3'd0;
            end
            bfs_head <= 3'd0; bfs_tail <= 3'd0;
            for (i = 0; i < MAX_N; i = i + 1) bfs_vis[i] <= 1'b0;
            if (n_r > 3'd0) begin
              bfs_q[0] <= 3'd0;
              bfs_tail <= 3'd1;
              bfs_vis[0] <= 1'b1;
              comp_id[0] <= 3'd0;
            end
          end
          if (bfs_head != bfs_tail) begin
            reg [2:0] u;
            u = bfs_q[bfs_head];
            bfs_head <= bfs_head + 3'd1;
            // Traverse all edges of u; if not a bridge, go to neighbor with same component
            for (i = 0; i < MAX_E; i = i + 1) begin
              if (i < adj_deg[u]) begin
                reg [2:0] v, ei;
                v = adj_v[u][i];
                ei = i;
                if (!is_bridge[ei]) begin
                  if (!bfs_vis[v]) begin
                    bfs_vis[v] <= 1'b1;
                    comp_id[v] <= comp_cnt;
                    bfs_q[bfs_tail] <= v;
                    bfs_tail <= bfs_tail + 3'd1;
                  end
                end else begin
                  // This edge is a bridge; orient it parent->child for later use
                  // Ensure bridge_u/v have consistent orientation parent->child
                  // Detect orientation
                  if (parent_node[v] == u) begin
                    bridge_u[ei] <= u;
                    bridge_v[ei] <= v;
                  end else if (parent_node[u] == v) begin
                    bridge_u[ei] <= v;
                    bridge_v[ei] <= u;
                  end else begin
                    // Fallback: keep as-is; will not affect connectivity logic
                  end
                end
              end
            end
          end else begin
            // Current component finished
            comp_cnt <= comp_cnt + 3'd1;
            // Check if all nodes assigned
            // find next unassigned node < n_r
            reg [2:0] found;
            found = 3'd0;
            for (i = 0; i < MAX_N; i = i + 1) begin
              if (i < n_r && comp_id[i] == 3'd0 && !found) found = i;
            end
            if (found) begin
              bfs_q[0] <= found;
              bfs_tail <= 3'd1;
              for (i = 0; i < MAX_N; i = i + 1) bfs_vis[i] <= 1'b0;
              bfs_vis[found] <= 1'b1;
              comp_id[found] <= comp_cnt; // assign new component id
            end else begin
              // All components assigned; proceed to build bridge tree edges
              // For each bridge, set comp_of_edge, and comp adjacency
              if (out_idx < bridge_cnt) begin
                reg [2:0] bu, bv, ci, cj;
                bu = bridge_u[out_idx];
                bv = bridge_v[out_idx];
                ci = comp_id[bu];
                cj = comp_id[bv];
                comp_of_edge[out_idx] <= (ci < cj) ? ci : cj; // store min comp id for edge
                // Add to adjacency of ci and cj
                i = comp_adj_deg[ci];
                if (i < MAX_E) begin
                  comp_u[ci][i] <= ci;
                  comp_v[ci][i] <= cj;
                  comp_adj_deg[ci] <= comp_adj_deg[ci] + 3'd1;
                  comp_deg[ci] <= comp_deg[ci] + 3'd1;
                  comp_deg[cj] <= comp_deg[cj] + 3'd1;
                end
                i = comp_adj_deg[cj];
                if (i < MAX_E) begin
                  comp_u[cj][i] <= cj;
                  comp_v[cj][i] <= ci;
                  comp_adj_deg[cj] <= comp_adj_deg[cj] + 3'd1;
                end
                out_idx <= out_idx + 3'd1;
              end else begin
                // Compute leaves of bridge-tree (degree == 1)
                leaf_cnt <= 3'd0;
                leaf_head <= 3'd0;
                leaf_tail <= 3'd0;
                for (i = 0; i < MAX_N; i = i + 1) leaf_buf[i] <= 3'd0;
                for (i = 0; i < MAX_N; i = i + 1) begin
                  if (i < comp_cnt && comp_deg[i] == 3'd1) begin
                    leaf_buf[leaf_tail] <= i;
                    leaf_tail <= leaf_tail + 3'd1;
                  end
                end
                leaf_cnt <= leaf_tail; // number of leaves
                add_ptr <= 3'd0;
                out_idx <= 3'd0;
                state <= CONNECT_COMPONENTS;
              end
            end
          end
        end

        CONNECT_COMPONENTS: begin
          // Pair leaves to add edges that connect different bridge-tree components
          // One operation per cycle
          if (add_ptr < leaf_cnt) begin
            if (pair_first == 3'd7) begin
              // First of pair
              pair_first <= leaf_buf[add_ptr];
              add_ptr <= add_ptr + 3'd1;
            end else begin
              // Second of pair -> compute shortest path between the two leaves
              reg [2:0] a_comp, b_comp, src, dst;
              a_comp = pair_first;
              b_comp = leaf_buf[add_ptr];
              add_ptr <= add_ptr + 3'd1;
              pair_first <= 3'd7; // reset
              // Map component -> any original node within it
              // Find representative node for each component
              src = 3'd0; dst = 3'd0;
              for (i = 0; i < MAX_N; i = i + 1) begin
                if (i < n_r && comp_id[i] == a_comp) src = i;
              end
              for (i = 0; i < MAX_N; i = i + 1) begin
                if (i < n_r && comp_id[i] == b_comp) dst = i;
              end
              // BFS to find shortest path between src and dst using original adjacency
              for (i = 0; i < MAX_N; i = i + 1) begin
                bfs_vis[i] <= 1'b0;
                prev_node[i] <= 3'd0;
                prev_edge[i] <= 3'd0;
              end
              bfs_head <= 3'd0; bfs_tail <= 3'd0;
              bfs_q[0] <= src;
              bfs_tail <= 3'd1;
              bfs_vis[src] <= 1'b1;
              // Run BFS until dst found or queue empty
              path_len <= 3'd0;
              // BFS loop: proceed until found; may take multiple cycles but total bounded
              while (bfs_head != bfs_tail && !bfs_vis[dst]) begin
                reg [2:0] u;
                u = bfs_q[bfs_head];
                bfs_head <= bfs_head + 3'd1;
                for (i = 0; i < MAX_E; i = i + 1) begin
                  if (i < adj_deg[u]) begin
                    reg [2:0] v;
                    v = adj_v[u][i];
                    if (!bfs_vis[v]) begin
                      bfs_vis[v] <= 1'b1;
                      prev_node[v] <= u;
                      prev_edge[v] <= i;
                      bfs_q[bfs_tail] <= v;
                      bfs_tail <= bfs_tail + 3'd1;
                    end
                  end
                end
              end
              // Reconstruct first edge of path src->dst
              if (bfs_vis[dst]) begin
                reg [2:0] cur;
                cur = dst;
                // Walk back until parent is src (first step)
                while (prev_node[cur] != src) begin
                  cur = prev_node[cur];
                end
                // The first edge is (src, cur)
                add_u[out_idx] <= {3'b0, src};
                add_v[out_idx] <= {3'b0, cur};
                out_idx <= out_idx + 3'd1;
              end else begin
                // Should not happen in a tree; fallback to direct head nodes
                add_u[out_idx] <= {3'b0, src};
                add_v[out_idx] <= {3'b0, dst};
                out_idx <= out_idx + 3'd1;
              end
            end
          end else begin
            // Finished pairing leaves
            if (pair_first != 3'd7) begin
              // If odd number of leaves, pair the last with headquarters' component (self-loop has no effect but satisfies algorithm)
              // Use HQ representative node if possible; else node 0
              reg [2:0] rep;
              rep = (h_r < n_r) ? h_r : 3'd0;
              // Map pair_first component to a rep node
              for (i = 0; i < MAX_N; i = i + 1) begin
                if (i < n_r && comp_id[i] == pair_first) rep = i;
              end
              add_u[out_idx] <= {3'b0, rep};
              add_v[out_idx] <= {3'b0, rep};
              out_idx <= out_idx + 3'd1;
              pair_first <= 3'd7;
            end
            // Set outputs and finish
            m <= out_idx; // number of added edges
            // Pack added_edges in the same format: 6 bits per pair (a:3b, b:3b)
            added_edges <= 42'd0;
            for (i = 0; i < MAX_E; i = i + 1) begin
              if (i < out_idx) begin
                added_edges[(6*i + 5) -: 3] <= add_u[i][2:0];
                added_edges[(6*i + 0) -: 3] <= add_v[i][2:0];
              end else begin
                // pad with zeros
                added_edges[(6*i + 5) -: 3] <= 3'd0;
                added_edges[(6*i + 0) -: 3] <= 3'd0;
              end
            end
            done <= 1'b1;
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

  // Next-state logic (combinational) - simple pass-through for this design
  always @(*) begin
    next_state = state;
  end
endmodule