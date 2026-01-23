module graph_profit_maximizer (
  input clk,
  input rst_n,
  input start,
  input [8:0] node_idx,
  input [8:0] edge_idx,
  input load_mode,
  input signed [31:0] A_val,
  input signed [31:0] B_val,
  input [8:0] U_val,
  input [8:0] V_val,
  output reg [31:0] max_profit,
  output reg done
);

  // Parameters
  parameter MAX_NODES = 300;
  parameter MAX_EDGES = 300;
  parameter INF = 30'h3FFFFFFF; // Large constant for infinity
  parameter S = MAX_NODES; // Source index
  parameter T = MAX_NODES + 1; // Sink index
  parameter TOTAL_NODES = MAX_NODES + 2;

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    LOAD_NODES,
    LOAD_EDGES,
    COMPUTE,
    BFS,
    DFS,
    CALCULATE
  } state_t;

  state_t state, next_state;

  // Internal signals
  reg [8:0] node_count;
  reg [8:0] edge_count;
  reg [31:0] total_positive_B;
  reg [31:0] max_flow;

  // BRAMs for graph storage
  reg signed [31:0] A_ram [0:MAX_NODES-1];
  reg signed [31:0] B_ram [0:MAX_NODES-1];
  reg [31:0] cap_ram [0:TOTAL_NODES-1][0:TOTAL_NODES-1];
  reg [8:0] dist_ram [0:TOTAL_NODES-1];
  reg [8:0] ptr_ram [0:TOTAL_NODES-1];

  // BFS/DFS signals
  reg [8:0] bfs_queue [0:TOTAL_NODES-1];
  reg [8:0] bfs_head, bfs_tail;
  reg [8:0] dfs_stack [0:TOTAL_NODES-1];
  reg [8:0] dfs_top;
  reg [31:0] flow;

  // Initialize BRAMs
  integer i, j;
  initial begin
    for (i = 0; i < MAX_NODES; i = i + 1) begin
      A_ram[i] = 0;
      B_ram[i] = 0;
    end
    for (i = 0; i < TOTAL_NODES; i = i + 1) begin
      for (j = 0; j < TOTAL_NODES; j = j + 1) begin
        cap_ram[i][j] = 0;
      end
    end
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      node_count <= 0;
      edge_count <= 0;
      total_positive_B <= 0;
      max_flow <= 0;
      max_profit <= 0;
      done <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = LOAD_NODES;
      end
      LOAD_NODES: begin
        if (load_mode == 1) next_state = LOAD_EDGES;
      end
      LOAD_EDGES: begin
        if (start) next_state = COMPUTE;
      end
      COMPUTE: next_state = BFS;
      BFS: next_state = DFS;
      DFS: next_state = CALCULATE;
      CALCULATE: next_state = IDLE;
    endcase
  end

  // Load nodes
  always @(posedge clk) begin
    if (state == LOAD_NODES && load_mode == 0) begin
      A_ram[node_idx] <= A_val;
      B_ram[node_idx] <= B_val;
      if (B_val > 0) total_positive_B <= total_positive_B + B_val;
      node_count <= node_idx + 1;
    end
  end

  // Load edges
  always @(posedge clk) begin
    if (state == LOAD_EDGES && load_mode == 1) begin
      // Forward edge
      cap_ram[U_val][V_val] <= INF;
      // Reverse edge
      cap_ram[V_val][U_val] <= INF;
      edge_count <= edge_idx + 1;
    end
  end

  // Construct flow network
  always @(posedge clk) begin
    if (state == COMPUTE) begin
      // Add source and sink edges
      for (i = 0; i < node_count; i = i + 1) begin
        if (B_ram[i] > 0) begin
          cap_ram[S][i] <= B_ram[i];
        end else if (B_ram[i] < 0) begin
          cap_ram[i][T] <= -B_ram[i];
        end
      end
    end
  end

  // BFS for level graph
  always @(posedge clk) begin
    if (state == BFS) begin
      // Initialize
      for (i = 0; i < TOTAL_NODES; i = i + 1) begin
        dist_ram[i] <= 32'hFFFFFFFF;
      end
      dist_ram[S] <= 0;
      bfs_head <= 0;
      bfs_tail <= 1;
      bfs_queue[0] <= S;

      // BFS loop
      while (bfs_head < bfs_tail) begin
        reg [8:0] u = bfs_queue[bfs_head];
        bfs_head <= bfs_head + 1;
        for (i = 0; i < TOTAL_NODES; i = i + 1) begin
          if (cap_ram[u][i] > 0 && dist_ram[i] == 32'hFFFFFFFF) begin
            dist_ram[i] <= dist_ram[u] + 1;
            bfs_queue[bfs_tail] <= i;
            bfs_tail <= bfs_tail + 1;
          end
        end
      end
    end
  end

  // DFS for blocking flow
  always @(posedge clk) begin
    if (state == DFS) begin
      // Initialize
      for (i = 0; i < TOTAL_NODES; i = i + 1) begin
        ptr_ram[i] <= 0;
      end
      dfs_top <= 0;
      flow <= 0;

      // DFS loop
      while (dfs_top >= 0) begin
        reg [8:0] u = dfs_stack[dfs_top];
        if (u == T) begin
          // Found a path, update flow
          reg [31:0] min_cap = 32'hFFFFFFFF;
          for (i = 0; i < dfs_top; i = i + 1) begin
            reg [8:0] v = dfs_stack[i+1];
            if (cap_ram[u][v] < min_cap) min_cap = cap_ram[u][v];
          end
          flow <= flow + min_cap;
          // Update capacities
          for (i = 0; i < dfs_top; i = i + 1) begin
            reg [8:0] v = dfs_stack[i+1];
            cap_ram[u][v] <= cap_ram[u][v] - min_cap;
            cap_ram[v][u] <= cap_ram[v][u] + min_cap;
          end
          dfs_top <= dfs_top - 1;
        end else begin
          reg [8:0] v = ptr_ram[u];
          if (v < TOTAL_NODES && cap_ram[u][v] > 0 && dist_ram[v] == dist_ram[u] + 1) begin
            ptr_ram[u] <= v + 1;
            dfs_stack[dfs_top+1] <= v;
            dfs_top <= dfs_top + 1;
          end else begin
            ptr_ram[u] <= 0;
            dfs_top <= dfs_top - 1;
          end
        end
      end
      max_flow <= flow;
    end
  end

  // Calculate result
  always @(posedge clk) begin
    if (state == CALCULATE) begin
      max_profit <= total_positive_B - max_flow;
      done <= 1;
    end
  end

endmodule