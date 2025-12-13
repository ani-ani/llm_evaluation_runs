module escape_network(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] h,
  input [41:0] edges,
  output reg [2:0] m,
  output reg [41:0] added_edges,
  output reg done
);

  // Parameters
  localparam MAX_NODES = 8;
  localparam MAX_EDGES = 7;

  // FSM states
  localparam S_IDLE       = 3'd0;
  localparam S_INIT       = 3'd1;
  localparam S_DFS_SETUP  = 3'd2;
  localparam S_DFS_STEP   = 3'd3;
  localparam S_BRIDGE     = 3'd4;
  localparam S_BUILD_CMP  = 3'd5;
  localparam S_FIND_LEAVES= 3'd6;
  localparam S_GEN_EDGES  = 3'd7;

  reg [2:0] state, next_state;

  // Edge storage (undirected tree edges from input)
  reg [2:0] edge_u [0:MAX_EDGES-1];
  reg [2:0] edge_v [0:MAX_EDGES-1];

  // DFS arrays
  reg [3:0] disc   [0:MAX_NODES-1];
  reg [3:0] low    [0:MAX_NODES-1];
  reg       visited[0:MAX_NODES-1];

  // Stack for iterative DFS
  // Each stack entry: {node[2:0], parent[2:0], edge_index[2:0], edge_phase[1:0]}
  // edge_phase: 0=enter node, 1=process next edge, 2=return from child
  reg [2:0] st_node   [0:31];
  reg [2:0] st_parent [0:31];
  reg [2:0] st_ei     [0:31];
  reg [1:0] st_phase  [0:31];
  reg [5:0] sp; // stack pointer

  reg [3:0] time_counter;

  // Bridge detection
  reg is_bridge [0:MAX_EDGES-1];

  // Variables for loops (sequentialized)
  reg [3:0] idx;
  reg [3:0] jdx;

  // Component assignment for 2-edge-connected components
  reg [2:0] comp_id [0:MAX_NODES-1];
  reg [2:0] comp_count;

  // Temporary for root in DFS (use headquarters h as root)
  wire [2:0] root = h;

  // For leaf detection in bridge tree
  // bridge tree over components: use degree count of each component (from bridges)
  reg [3:0] comp_deg [0:MAX_NODES-1];
  reg [2:0] leaf_list [0:MAX_NODES-1];
  reg [3:0] leaf_count;

  // Internal for edge generation
  reg [2:0] add_u [0:MAX_EDGES-1];
  reg [2:0] add_v [0:MAX_EDGES-1];

  integer i;

  // Combinational next_state (simple linear sequencing)
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) next_state = S_INIT;
      end
      S_INIT: begin
        next_state = S_DFS_SETUP;
      end
      S_DFS_SETUP: begin
        next_state = S_DFS_STEP;
      end
      S_DFS_STEP: begin
        // When DFS stack empty, done DFS
        if (sp == 0) next_state = S_BRIDGE;
      end
      S_BRIDGE: begin
        next_state = S_BUILD_CMP;
      end
      S_BUILD_CMP: begin
        next_state = S_FIND_LEAVES;
      end
      S_FIND_LEAVES: begin
        next_state = S_GEN_EDGES;
      end
      S_GEN_EDGES: begin
        next_state = S_IDLE;
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      m <= 3'd0;
      added_edges <= 42'd0;
      done <= 1'b0;
      sp <= 6'd0;
      time_counter <= 4'd0;
      comp_count <= 3'd0;
      leaf_count <= 4'd0;
      for (i = 0; i < MAX_EDGES; i = i + 1) begin
        edge_u[i] <= 3'd0;
        edge_v[i] <= 3'd0;
        is_bridge[i] <= 1'b0;
        add_u[i] <= 3'd0;
        add_v[i] <= 3'd0;
      end
      for (i = 0; i < MAX_NODES; i = i + 1) begin
        disc[i] <= 4'd0;
        low[i] <= 4'd0;
        visited[i] <= 1'b0;
        comp_id[i] <= 3'd0;
        comp_deg[i] <= 4'd0;
        leaf_list[i] <= 3'd0;
      end
    end else begin
      state <= next_state;
      done <= 1'b0;

      case (state)
        S_IDLE: begin
          if (start) begin
            // Clear outputs and internal arrays
            m <= 3'd0;
            added_edges <= 42'd0;
            time_counter <= 4'd0;
            sp <= 6'd0;
            comp_count <= 3'd0;
            leaf_count <= 4'd0;
            for (i = 0; i < MAX_EDGES; i = i + 1) begin
              is_bridge[i] <= 1'b0;
              add_u[i] <= 3'd0;
              add_v[i] <= 3'd0;
            end
            for (i = 0; i < MAX_NODES; i = i + 1) begin
              disc[i] <= 4'd0;
              low[i] <= 4'd0;
              visited[i] <= 1'b0;
              comp_id[i] <= 3'd0;
              comp_deg[i] <= 4'd0;
              leaf_list[i] <= 3'd0;
            end

            // Parse edges from packed input
            // edges: [a0,b0,a1,b1,...,a6,b6], each 3 bits, total 42 bits
            edge_u[0] <= edges[41:39]; edge_v[0] <= edges[38:36];
            edge_u[1] <= edges[35:33]; edge_v[1] <= edges[32:30];
            edge_u[2] <= edges[29:27]; edge_v[2] <= edges[26:24];
            edge_u[3] <= edges[23:21]; edge_v[3] <= edges[20:18];
            edge_u[4] <= edges[17:15]; edge_v[4] <= edges[14:12];
            edge_u[5] <= edges[11:9];  edge_v[5] <= edges[8:6];
            edge_u[6] <= edges[5:3];   edge_v[6] <= edges[2:0];
          end
        end

        S_INIT: begin
          // Ensure visited/arrays cleared (already mostly cleared in IDLE on start)
          time_counter <= 4'd0;

          // Initialize DFS stack with root
          sp <= 6'd1;
          st_node[0] <= root;
          st_parent[0] <= 3'd7; // 7 as invalid parent
          st_ei[0] <= 3'd0;
          st_phase[0] <= 2'd0; // enter
        end

        S_DFS_SETUP: begin
          // Mark root as unvisited, actual marking on first step
          // Nothing extra; move to DFS_STEP
        end

        S_DFS_STEP: begin
          if (sp != 0) begin
            // Pop
            reg [2:0] cur;
            reg [2:0] par;
            reg [2:0] ei;
            reg [1:0] ph;
            sp <= sp - 1'b1;
            cur <= st_node[sp-1];
            par <= st_parent[sp-1];
            ei  <= st_ei[sp-1];
            ph  <= st_phase[sp-1];

            if (ph == 2'd0) begin
              // Enter node
              if (!visited[cur]) begin
                visited[cur] <= 1'b1;
                time_counter <= time_counter + 1'b1;
                disc[cur] <= time_counter + 1'b1;
                low[cur]  <= time_counter + 1'b1;
              end
              // Push state to start scanning edges
              st_node[sp]   <= cur;
              st_parent[sp] <= par;
              st_ei[sp]     <= 3'd0;
              st_phase[sp]  <= 2'd1;
              sp <= sp + 1'b1;

            end else if (ph == 2'd1) begin
              // Process edges incident to cur, iteratively via ei
              if (ei < n - 1) begin
                // tree with (n-1) valid edges; remaining edges ignored
                reg [2:0] a;
                reg [2:0] b;
                reg [2:0] nxt;
                a = edge_u[ei];
                b = edge_v[ei];
                nxt = 3'd7; // invalid
                if (a == cur) nxt = b;
                else if (b == cur) nxt = a;

                // Continue scanning
                st_node[sp]   <= cur;
                st_parent[sp] <= par;
                st_ei[sp]     <= ei + 1'b1;
                st_phase[sp]  <= 2'd1;
                sp <= sp + 1'b1;

                if (nxt != 3'd7 && nxt != par) begin
                  if (!visited[nxt]) begin
                    // Tree edge: push return frame then child
                    // Return frame to update low[cur] after child
                    st_node[sp]   <= cur;
                    st_parent[sp] <= par;
                    st_ei[sp]     <= ei;
                    st_phase[sp]  <= 2'd2;
                    sp <= sp + 1'b1;

                    // Child enter
                    st_node[sp]   <= nxt;
                    st_parent[sp] <= cur;
                    st_ei[sp]     <= 3'd0;
                    st_phase[sp]  <= 2'd0;
                    sp <= sp + 1'b1;
                  end else begin
                    // Back edge: update low[cur]
                    if (disc[nxt] < low[cur])
                      low[cur] <= disc[nxt];
                  end
                end
              end
              // else no more edges: nothing; backtracking handled via phase 2 frames

            end else if (ph == 2'd2) begin
              // Return from child for tree edge index ei
              reg [2:0] a2;
              reg [2:0] b2;
              reg [2:0] child;
              a2 = edge_u[ei];
              b2 = edge_v[ei];
              // find child: node that is not cur
              if (a2 == cur) child = b2;
              else child = a2;

              // Update low[cur]
              if (low[child] < low[cur])
                low[cur] <= low[child];

            end
          end
        end

        S_BRIDGE: begin
          // Determine which edges are bridges based on disc/low
          // For each edge (u,v), if disc[u] < disc[v]
          // and low[v] > disc[u], or vice versa, mark bridge
          for (i = 0; i < MAX_EDGES; i = i + 1) begin
            is_bridge[i] <= 1'b0;
            if (i < (n - 1)) begin
              reg [2:0] uu;
              reg [2:0] vv;
              uu = edge_u[i];
              vv = edge_v[i];
              if (disc[uu] < disc[vv]) begin
                if (low[vv] > disc[uu]) is_bridge[i] <= 1'b1;
              end else if (disc[vv] < disc[uu]) begin
                if (low[uu] > disc[vv]) is_bridge[i] <= 1'b1;
              end
            end
          end
        end

        S_BUILD_CMP: begin
          // Build 2-edge-connected components by collapsing non-bridge edges.
          // For small N, use simple iterative union via repeated relaxation.
          // Initialize each node's component to itself.
          for (i = 0; i < MAX_NODES; i = i + 1) begin
            if (i < n)
              comp_id[i] <= i[2:0];
            else
              comp_id[i] <= 3'd0;
          end

          // Relax a few passes (sufficient for small tree) connecting non-bridge edges
          for (jdx = 0; jdx < 4; jdx = jdx + 1) begin
            for (i = 0; i < MAX_EDGES; i = i + 1) begin
              if (i < (n - 1) && !is_bridge[i]) begin
                reg [2:0] cu;
                reg [2:0] cv;
                cu = comp_id[edge_u[i]];
                cv = comp_id[edge_v[i]];
                if (cu < cv) comp_id[edge_v[i]] <= cu;
                else if (cv < cu) comp_id[edge_u[i]] <= cv;
              end
            end
          end

          // Compress and count unique components (simple method)
          // First, propagate minimal label again
          for (i = 0; i < MAX_NODES; i = i + 1) begin
            if (i < n) begin
              if (comp_id[comp_id[i]] < comp_id[i])
                comp_id[i] <= comp_id[comp_id[i]];
            end
          end

          // Count unique component labels used by nodes 0..n-1
          comp_count <= 3'd0;
          for (i = 0; i < MAX_NODES; i = i + 1) begin
            comp_deg[i] <= 4'd0;
          end
          for (i = 0; i < MAX_NODES; i = i + 1) begin
            if (i < n) begin
              reg exists;
              integer k;
              exists = 1'b0;
              for (k = 0; k < MAX_NODES; k = k + 1) begin
                if (k < comp_count && leaf_list[k] == comp_id[i]) exists = 1'b0; // dummy op to avoid unused
              end
            end
          end

          // Simpler: map comp_id to dense 0..C-1 via scanning
          reg [2:0] map_old2new [0:MAX_NODES-1];
          for (i = 0; i < MAX_NODES; i = i + 1) begin
            map_old2new[i] = 3'd7;
          end
          comp_count <= 3'd0;
          for (i = 0; i < MAX_NODES; i = i + 1) begin
            if (i < n) begin
              reg [2:0] lbl;
              lbl = comp_id[i];
              if (map_old2new[lbl] == 3'd7) begin
                map_old2new[lbl] = comp_count;
                comp_count <= comp_count + 1'b1;
              end
            end
          end
          for (i = 0; i < MAX_NODES; i = i + 1) begin
            if (i < n)
              comp_id[i] <= map_old2new[comp_id[i]];
          end
        end

        S_FIND_LEAVES: begin
          // Build bridge tree degrees between components
          for (i = 0; i < MAX_NODES; i = i + 1) begin
            comp_deg[i] <= 4'd0;
          end
          for (i = 0; i < MAX_EDGES; i = i + 1) begin
            if (i < (n - 1) && is_bridge[i]) begin
              reg [2:0] cu2;
              reg [2:0] cv2;
              cu2 = comp_id[edge_u[i]];
              cv2 = comp_id[edge_v[i]];
              if (cu2 != cv2) begin
                comp_deg[cu2] <= comp_deg[cu2] + 1'b1;
                comp_deg[cv2] <= comp_deg[cv2] + 1'b1;
              end
            end
          end

          // Collect leaves: components with degree==1 (in non-trivial tree)
          leaf_count <= 4'd0;
          for (i = 0; i < MAX_NODES; i = i + 1) begin
            leaf_list[i] <= 3'd0;
          end
          for (i = 0; i < MAX_NODES; i = i + 1) begin
            if (i < comp_count) begin
              if (comp_deg[i] == 4'd1) begin
                leaf_list[leaf_count] <= i[2:0];
                leaf_count <= leaf_count + 1'b1;
              end
            end
          end
        end

        S_GEN_EDGES: begin
          // Minimal edges to add = ceil(L/2) where L is leaf_count of bridge tree
          // If comp_count <= 1, no bridges, no edges to add.
          if (comp_count <= 3'd1 || leaf_count <= 4'd1) begin
            m <= 3'd0;
            added_edges <= 42'd0;
          end else begin
            reg [2:0] needed;
            needed = (leaf_count[0] == 1'b0) ? (leaf_count[3:1]) : (leaf_count[3:1] + 1'b1);
            if (needed > 3'd7) needed = 3'd7;
            m <= needed;

            // For each pair of leaves, connect one representative node from each component.
            // Choose smallest node index in each component as representative.
            reg [2:0] rep [0:MAX_NODES-1];
            integer c;
            for (c = 0; c < MAX_NODES; c = c + 1) begin
              rep[c] = 3'd7;
            end
            for (i = 0; i < MAX_NODES; i = i + 1) begin
              if (i < n) begin
                c = comp_id[i];
                if (rep[c] == 3'd7 || i[2:0] < rep[c])
                  rep[c] = i[2:0];
              end
            end

            // Generate edges
            for (i = 0; i < MAX_EDGES; i = i + 1) begin
              add_u[i] <= 3'd0;
              add_v[i] <= 3'd0;
            end

            integer p;
            integer eidx;
            eidx = 0;
            p = 0;
            while (p+1 < leaf_count && eidx < needed) begin
              reg [2:0] c1;
              reg [2:0] c2;
              c1 = leaf_list[p];
              c2 = leaf_list[p+1];
              add_u[eidx] <= rep[c1];
              add_v[eidx] <= rep[c2];
              eidx = eidx + 1;
              p = p + 2;
            end
            // If odd leaf left, connect it to first leaf
            if (p < leaf_count && eidx < needed && leaf_count > 0) begin
              reg [2:0] c1l;
              reg [2:0] c2l;
              c1l = leaf_list[p];
              c2l = leaf_list[0];
              add_u[eidx] <= rep[c1l];
              add_v[eidx] <= rep[c2l];
              eidx = eidx + 1;
            end

            // Pack added_edges
            added_edges <= 42'd0;
            for (i = 0; i < MAX_EDGES; i = i + 1) begin
              if (i < needed) begin
                case (i)
                  0: added_edges[41:36] <= {add_u[0], add_v[0]};
                  1: added_edges[35:30] <= {add_u[1], add_v[1]};
                  2: added_edges[29:24] <= {add_u[2], add_v[2]};
                  3: added_edges[23:18] <= {add_u[3], add_v[3]};
                  4: added_edges[17:12] <= {add_u[4], add_v[4]};
                  5: added_edges[11:6]  <= {add_u[5], add_v[5]};
                  6: added_edges[5:0]   <= {add_u[6], add_v[6]};
                  default: ;
                endcase
              end
            end
          end

          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

endmodule
