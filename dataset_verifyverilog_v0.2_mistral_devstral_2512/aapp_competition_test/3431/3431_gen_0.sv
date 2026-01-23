module mst_weight (
  input clk,
  input rst_n,
  input start,
  input [2:0] n_points,
  input [9:0] points [0:7],
  output reg [15:0] mst_weight,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    EXTRACT,
    COMPUTE_EDGES,
    SORT_EDGES,
    KRUSKAL,
    DONE
  } state_t;

  state_t state, next_state;

  // Extracted coordinates
  logic [4:0] x [0:7], y [0:7];

  // Edge storage: {weight, u, v}
  logic [5:0] edge_weight [0:27];
  logic [2:0] edge_u [0:27], edge_v [0:27];
  logic [5:0] sorted_weight [0:27];
  logic [2:0] sorted_u [0:27], sorted_v [0:27];

  // Union-Find data structures
  logic [2:0] parent [0:7];
  logic [2:0] rank [0:7];

  // Counters and control signals
  logic [4:0] extract_cnt;
  logic [4:0] edge_cnt;
  logic [4:0] sort_pass;
  logic [4:0] sort_i;
  logic [4:0] kruskal_cnt;
  logic [4:0] mst_edges;
  logic [15:0] total_weight;

  // Temporary variables for computation
  logic [4:0] x1, y1, x2, y2;
  logic [5:0] manhattan_dist;
  logic [2:0] u, v;
  logic [2:0] root_u, root_v;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      mst_weight <= 0;
      extract_cnt <= 0;
      edge_cnt <= 0;
      sort_pass <= 0;
      sort_i <= 0;
      kruskal_cnt <= 0;
      mst_edges <= 0;
      total_weight <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = EXTRACT;
      end
      EXTRACT: begin
        if (extract_cnt == n_points) next_state = COMPUTE_EDGES;
      end
      COMPUTE_EDGES: begin
        if (edge_cnt == (n_points*(n_points-1))/2) next_state = SORT_EDGES;
      end
      SORT_EDGES: begin
        if (sort_pass == n_points) next_state = KRUSKAL;
      end
      KRUSKAL: begin
        if (mst_edges == n_points - 1) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Extract coordinates
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      extract_cnt <= 0;
    end else if (state == EXTRACT && extract_cnt < n_points) begin
      x[extract_cnt] <= points[extract_cnt][9:5];
      y[extract_cnt] <= points[extract_cnt][4:0];
      extract_cnt <= extract_cnt + 1;
    end
  end

  // Compute edges
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      edge_cnt <= 0;
    end else if (state == COMPUTE_EDGES && edge_cnt < (n_points*(n_points-1))/2) begin
      // Calculate edge index
      u = $clog2(edge_cnt + 1);
      v = edge_cnt + 1 - (1 << u);
      
      // Get coordinates
      x1 = x[u];
      y1 = y[u];
      x2 = x[v];
      y2 = y[v];
      
      // Compute Manhattan distance
      manhattan_dist = (x1 > x2) ? (x1 - x2) : (x2 - x1);
      manhattan_dist = manhattan_dist + ((y1 > y2) ? (y1 - y2) : (y2 - y1));
      
      // Store edge
      edge_weight[edge_cnt] <= manhattan_dist;
      edge_u[edge_cnt] <= u;
      edge_v[edge_cnt] <= v;
      
      edge_cnt <= edge_cnt + 1;
    end
  end

  // Sort edges using bubble sort
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sort_pass <= 0;
      sort_i <= 0;
    end else if (state == SORT_EDGES) begin
      if (sort_i == 0) begin
        // Initialize sorted array at start of each pass
        for (int i = 0; i < 28; i = i + 1) begin
          sorted_weight[i] <= edge_weight[i];
          sorted_u[i] <= edge_u[i];
          sorted_v[i] <= edge_v[i];
        end
      end
      
      // Bubble sort pass
      if (sort_i < (n_points*(n_points-1))/2 - sort_pass - 1) begin
        if (sorted_weight[sort_i] > sorted_weight[sort_i + 1]) begin
          // Swap
          logic [5:0] temp_weight = sorted_weight[sort_i];
          logic [2:0] temp_u = sorted_u[sort_i];
          logic [2:0] temp_v = sorted_v[sort_i];
          
          sorted_weight[sort_i] <= sorted_weight[sort_i + 1];
          sorted_u[sort_i] <= sorted_u[sort_i + 1];
          sorted_v[sort_i] <= sorted_v[sort_i + 1];
          
          sorted_weight[sort_i + 1] <= temp_weight;
          sorted_u[sort_i + 1] <= temp_u;
          sorted_v[sort_i + 1] <= temp_v;
        end
        sort_i <= sort_i + 1;
      end else begin
        sort_i <= 0;
        sort_pass <= sort_pass + 1;
      end
    end
  end

  // Kruskal's algorithm with Union-Find
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      kruskal_cnt <= 0;
      mst_edges <= 0;
      total_weight <= 0;
      // Initialize Union-Find
      for (int i = 0; i < 8; i = i + 1) begin
        parent[i] <= i;
        rank[i] <= 0;
      end
    end else if (state == KRUSKAL && mst_edges < n_points - 1) begin
      // Get next edge
      u = sorted_u[kruskal_cnt];
      v = sorted_v[kruskal_cnt];
      
      // Find roots
      root_u = u;
      while (parent[root_u] != root_u) begin
        root_u = parent[root_u];
      end
      
      root_v = v;
      while (parent[root_v] != root_v) begin
        root_v = parent[root_v];
      end
      
      // Union if different roots
      if (root_u != root_v) begin
        if (rank[root_u] < rank[root_v]) begin
          parent[root_u] <= root_v;
        end else if (rank[root_u] > rank[root_v]) begin
          parent[root_v] <= root_u;
        end else begin
          parent[root_v] <= root_u;
          rank[root_u] <= rank[root_u] + 1;
        end
        
        // Add to MST
        total_weight <= total_weight + sorted_weight[kruskal_cnt];
        mst_edges <= mst_edges + 1;
      end
      
      kruskal_cnt <= kruskal_cnt + 1;
    end
  end

  // Output results
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      mst_weight <= 0;
    end else if (state == DONE) begin
      done <= 1;
      mst_weight <= total_weight;
    end else if (state != DONE) begin
      done <= 0;
    end
  end

endmodule