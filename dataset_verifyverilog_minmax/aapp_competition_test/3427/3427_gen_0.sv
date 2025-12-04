module max_secure_rooms(
    input clk,
    input rst_n,
    input start,
    input [3:0] num_rooms,
    input [3:0] num_doors,
    input [31:0] door_data [0:15],
    output reg [2:0] result,
    output reg done
);

  typedef enum logic [2:0] {
    IDLE = 3'b000,
    BUILD_GRAPH = 3'b001,
    FIND_BRIDGES = 3'b010,
    EVAL_COMPONENTS = 3'b011,
    OUTPUT = 3'b100
  } state_t;

  state_t state;

  // Constants
  localparam MAX_N = 8;
  localparam MAX_M = 16;
  localparam EXT = 4'b1111; // external node encoding

  // Storage for built graph
  logic [MAX_N-1:0][MAX_M-1:0] adj;           // adjacency matrix (rooms only)
  logic [MAX_N-1:0][MAX_M-1:0] ext_adj;       // adjacency to external per node
  logic [3:0] valid_nodes [$];                // dynamic list of internal nodes 0..7
  logic [3:0] valid_nodes_array [0:MAX_N-1];  // indexed view for iteration
  logic [3:0] valid_cnt;                      // number of valid nodes
  logic [MAX_N-1:0] is_valid;                 // 1 if node is present (0..7)

  // Bridge detection state
  logic [3:0] degree [0:MAX_N-1];             // degree in built graph
  logic [3:0] disc [0:MAX_N-1];               // discovery time
  logic [3:0] low [0:MAX_N-1];                // low link value
  logic [MAX_N-1:0] visited;                  // visited flag for bridge DFS
  logic [3:0] parent [0:MAX_N-1];             // parent in DFS tree (-1 = none)
  logic [4:0] time_cnt;                       // discovery time counter (0..31)
  logic [3:0] stack_nodes [$];                // stack of nodes to process (DFS)
  logic [3:0] stack_pos [$];                  // stack of neighbor positions for each node
  logic [3:0] curr_node;                      // current node popped from stack
  logic [3:0] curr_pos;                       // current neighbor index position for curr_node
  logic [3:0] nbr;                            // current neighbor
  logic [3:0] curr_parent;                    // cached parent for curr_node
  logic [3:0] curr_disc;                      // cached discovery time for curr_node

  // Found bridges and evaluation
  logic [1:0][3:0] bridges [0:MAX_M-1];       // list of bridge edges (a,b)
  logic [3:0] bridge_cnt;                     // number of bridges found
  logic [3:0] curr_bridge_idx;                // index of bridge currently evaluated

  // Evaluation state for component sizes after removing a bridge
  logic [3:0] comp_size [0:MAX_N-1];          // component size for each node (valid subset)
  logic [MAX_N-1:0] comp_has_ext;             // 1 if component touches external
  logic [MAX_N-1:0] comp_visited;             // visited for component BFS/DFS
  logic [3:0] temp_stack [$];                 // temp stack for component DFS
  logic [3:0] max_comp;                       // best component size so far

  // Helper to set an adjacency bit
  function void set_adj(input [3:0] a, input [3:0] b);
    if ((a < 8) && (b < 8)) begin
      adj[a][b] = 1'b1;
      adj[b][a] = 1'b1;
      degree[a] = degree[a] + 1;
      degree[b] = degree[b] + 1;
    end
  endfunction

  // Helper to set external adjacency bit
  function void set_ext_adj(input [3:0] a);
    if (a < 8) begin
      ext_adj[a][0] = 1'b1; // single bit, only index 0 used
    end
  endfunction

  // Helper to check if a neighbor index is valid for current node
  function bit is_valid_nbr(input [3:0] u, input [3:0] pos);
    return (pos < degree[u]);
  endfunction

  // Helper to get neighbor v given current position pos along u's adjacency row
  function [3:0] get_nbr_at_pos(input [3:0] u, input [3:0] pos);
    integer i;
    bit [3:0] v = 0;
    int cnt = -1;
    for (i = 0; i < MAX_M; i++) begin
      if (adj[u][i]) begin
        cnt = cnt + 1;
        if (cnt == pos) begin
          v = i[3:0];
          break;
        end
      end
    end
    return v;
  endfunction

  // Helper to check if (a,b) equals current bridge
  function bit is_curr_bridge(input [3:0] a, input [3:0] b, input [3:0] idx);
    logic [3:0] ba, bb;
    ba = bridges[idx][0];
    bb = bridges[idx][1];
    return ((a == ba) && (b == bb)) || ((a == bb) && (b == ba));
  endfunction

  // Component DFS (after removing bridge idx): mark comp_visited and compute sizes on the fly
  task automatic dfs_component_start(input [3:0] s, input [3:0] rem_idx);
    int stack [$];
    bit ext_found;
    logic [3:0] node, neighbor;
    bit [3:0] pos;
    int comp_sz;
    bit internal_has_ext;
    bit [MAX_N-1:0] local_visited;
    local_visited = 0;
    comp_sz = 0;
    ext_found = 1'b0;
    stack.push_back(s);
    local_visited[s] = 1'b1;
    while (stack.size() > 0) begin
      node = stack.pop_back();
      comp_sz = comp_sz + 1;
      if (ext_adj[node][0]) ext_found = 1'b1;
      // traverse neighbors that are not the removed bridge
      for (pos = 0; pos < degree[node]; pos = pos + 1) begin
        neighbor = get_nbr_at_pos(node, pos);
        if (is_curr_bridge(node, neighbor, rem_idx)) continue;
        if (!local_visited[neighbor]) begin
          local_visited[neighbor] = 1'b1;
          stack.push_back(neighbor);
        end
      end
    end
    comp_visited[s] = local_visited[s]; // store visited mask in global reg
    comp_has_ext[s] = ext_found;
    comp_size[s] = comp_sz[3:0];
  endtask

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 3'b0;
      done <= 1'b0;
      // Clear storage
      adj <= '0;
      ext_adj <= '0;
      for (int i = 0; i < MAX_N; i++) begin
        degree[i] <= 4'b0;
        disc[i] <= 4'b0;
        low[i] <= 4'b0;
        visited[i] <= 1'b0;
        parent[i] <= 4'b0;
        is_valid[i] <= 1'b0;
        comp_visited[i] <= 1'b0;
        comp_has_ext[i] <= 1'b0;
        comp_size[i] <= 4'b0;
      end
      valid_nodes.delete();
      for (int i = 0; i < MAX_N; i++) valid_nodes_array[i] <= 4'b0;
      valid_cnt <= 4'b0;
      bridge_cnt <= 4'b0;
      curr_bridge_idx <= 4'b0;
      max_comp <= 4'b0;
      time_cnt <= 5'b0;
      stack_nodes.delete();
      stack_pos.delete();
      curr_node <= 4'b0;
      curr_pos <= 4'b0;
      curr_parent <= 4'b0;
      curr_disc <= 4'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Build graph from door_data
            state <= BUILD_GRAPH;
            // Initialize storage
            adj <= '0;
            ext_adj <= '0;
            for (int i = 0; i < MAX_N; i++) begin
              degree[i] <= 4'b0;
              disc[i] <= 4'b0;
              low[i] <= 4'b0;
              visited[i] <= 1'b0;
              parent[i] <= 4'b0;
              is_valid[i] <= 1'b0;
              comp_visited[i] <= 1'b0;
              comp_has_ext[i] <= 1'b0;
              comp_size[i] <= 4'b0;
            end
            valid_nodes.delete();
            for (int i = 0; i < MAX_N; i++) valid_nodes_array[i] <= 4'b0;
            valid_cnt <= 4'b0;
          end
        end

        BUILD_GRAPH: begin
          // Build adjacency for rooms only and track external connections
          // Single-cycle full build: O(16) edges
          for (int i = 0; i < MAX_M; i++) begin
            if (i < num_doors) begin
              logic [3:0] u, v;
              u = door_data[i][31:28];
              v = door_data[i][27:24];
              if (u == EXT && v < 8) begin
                set_ext_adj(v);
              end else if (v == EXT && u < 8) begin
                set_ext_adj(u);
              end else if (u < 8 && v < 8) begin
                set_adj(u, v);
              end
            end
          end
          // Build list of valid nodes and flag array
          for (int i = 0; i < MAX_N; i++) begin
            if (i < num_rooms) begin
              if (degree[i] > 0) begin
                is_valid[i] <= 1'b1;
                valid_nodes.push_back(i);
                valid_nodes_array[valid_cnt] <= i;
                valid_cnt <= valid_cnt + 1;
              end else begin
                is_valid[i] <= 1'b0;
              end
            end else begin
              is_valid[i] <= 1'b0;
            end
          end
          // Initialize bridge detection state
          for (int i = 0; i < MAX_N; i++) begin
            disc[i] <= 4'b0;
            low[i] <= 4'b0;
            visited[i] <= 1'b0;
            parent[i] <= 4'b0;
          end
          bridge_cnt <= 4'b0;
          time_cnt <= 5'b0;
          state <= FIND_BRIDGES;
        end

        FIND_BRIDGES: begin
          // Iterative DFS for bridges, single node at a time
          if (stack_nodes.size() > 0) begin
            curr_node <= stack_nodes.pop_back();
            curr_pos  <= stack_pos.pop_back();
            curr_parent <= parent[curr_node];
            curr_disc <= disc[curr_node];
            // Process current node
            if (curr_pos == 0) begin
              // At first visit: set disc and low if unvisited
              if (!visited[curr_node]) begin
                visited[curr_node] <= 1'b1;
                disc[curr_node] <= time_cnt[3:0];
                low[curr_node] <= time_cnt[3:0];
                time_cnt <= time_cnt + 1;
              end
            end
            // Visit neighbors sequentially
            if (is_valid_nbr(curr_node, curr_pos)) begin
              nbr <= get_nbr_at_pos(curr_node, curr_pos);
              if (nbr == curr_parent) begin
                // Skip parent edge; advance
                stack_nodes.push_back(curr_node);
                stack_pos.push_back(curr_pos + 1);
              end else begin
                if (!visited[nbr]) begin
                  // Tree edge: recurse
                  parent[nbr] <= curr_node;
                  stack_nodes.push_back(curr_node);
                  stack_pos.push_back(curr_pos + 1);
                  stack_nodes.push_back(nbr);
                  stack_pos.push_back(0);
                end else begin
                  // Back edge: update low
                  low[curr_node] <= (low[curr_node] < disc[nbr]) ? low[curr_node] : disc[nbr];
                  // Advance on this node
                  stack_nodes.push_back(curr_node);
                  stack_pos.push_back(curr_pos + 1);
                end
              end
            end else begin
              // Done with neighbors: pop and update low of parent
              if (curr_parent != 4'b0) begin // parent[unused] = 0, treat as no parent for 0 as well
                // We encoded 'no parent' as 4'b0; node 0 may exist; avoid mis-handling: check by degree logic
                if (curr_parent < 8) begin
                  logic [3:0] old_low;
                  old_low = low[curr_parent];
                  if (old_low > low[curr_node]) begin
                    low[curr_parent] <= low[curr_node];
                  end
                  // Bridge check (curr_node, parent)
                  if (low[curr_node] == curr_disc) begin
                    // Only count if both nodes are valid and not connected to external via other edges
                    // Bridges that include a node with external adjacency do not protect a component
                    if (is_valid[curr_node] && is_valid[curr_parent] && (!ext_adj[curr_node][0] || !ext_adj[curr_parent][0])) begin
                      // Avoid duplicate entry (order-insensitive)
                      logic [3:0] a, b;
                      a = curr_node;
                      b = curr_parent;
                      if (bridge_cnt == 0 || 
                          !((bridges[0][0] == a && bridges[0][1] == b) || (bridges[0][0] == b && bridges[0][1] == a))) begin
                        // Store in sorted order for reproducibility
                        if (a < b) begin
                          bridges[bridge_cnt][0] <= a;
                          bridges[bridge_cnt][1] <= b;
                        end else begin
                          bridges[bridge_cnt][0] <= b;
                          bridges[bridge_cnt][1] <= a;
                        end
                        bridge_cnt <= bridge_cnt + 1;
                      end
                    end
                  end
                end
              end
            end
          end else begin
            // Start a new tree root if any unvisited valid node remains
            logic [3:0] start_node;
            bit found_start;
            found_start = 1'b0;
            for (int i = 0; i < MAX_N; i++) begin
              if (is_valid[i] && !visited[i]) begin
                start_node = i[3:0];
                found_start = 1'b1;
                break;
              end
            end
            if (found_start) begin
              parent[start_node] <= 4'b0; // no parent
              stack_nodes.push_back(start_node);
              stack_pos.push_back(0);
            end else begin
              // Done finding bridges: move to evaluation
              state <= EVAL_COMPONENTS;
              curr_bridge_idx <= 4'b0;
              max_comp <= 4'b0;
            end
          end
        end

        EVAL_COMPONENTS: begin
          if (curr_bridge_idx < bridge_cnt) begin
            // Compute component sizes for all valid nodes (not visited) after removing curr_bridge_idx
            for (int i = 0; i < MAX_N; i++) begin
              comp_visited[i] <= 1'b0;
              comp_has_ext[i] <= 1'b0;
              comp_size[i] <= 4'b0;
            end
            for (int i = 0; i < valid_cnt; i++) begin
              logic [3:0] s;
              s = valid_nodes_array[i];
              if (!comp_visited[s]) begin
                // Run component DFS from s using curr_bridge_idx
                int stack [$];
                bit ext_found;
                logic [3:0] node, neighbor;
                bit [3:0] pos;
                int comp_sz;
                bit [MAX_N-1:0] local_visited;
                local_visited = 0;
                ext_found = 1'b0;
                comp_sz = 0;
                stack.push_back(s);
                local_visited[s] = 1'b1;
                while (stack.size() > 0) begin
                  node = stack.pop_back();
                  comp_sz = comp_sz + 1;
                  if (ext_adj[node][0]) ext_found = 1'b1;
                  for (pos = 0; pos < degree[node]; pos = pos + 1) begin
                    neighbor = get_nbr_at_pos(node, pos);
                    if (is_curr_bridge(node, neighbor, curr_bridge_idx)) continue;
                    if (!local_visited[neighbor]) begin
                      local_visited[neighbor] = 1'b1;
                      stack.push_back(neighbor);
                    end
                  end
                end
                comp_visited[s] <= local_visited[s];
                comp_has_ext[s] <= ext_found;
                comp_size[s] <= comp_sz[3:0];
              end
            end
            // Determine the best component (largest without external connection) among these
            logic [3:0] best_curr;
            best_curr = 4'b0;
            for (int i = 0; i < valid_cnt; i++) begin
              logic [3:0] n;
              n = valid_nodes_array[i];
              if (comp_visited[n] && !comp_has_ext[n]) begin
                if (comp_size[n] > best_curr) begin
                  best_curr = comp_size[n];
                end
              end
            end
            if (best_curr > max_comp) begin
              max_comp <= best_curr;
            end
            curr_bridge_idx <= curr_bridge_idx + 1;
          end else begin
            state <= OUTPUT;
          end
        end

        OUTPUT: begin
          result <= max_comp[2:0];
          done <= 1'b1;
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule
