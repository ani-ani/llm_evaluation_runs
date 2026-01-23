module network_optimizer (
  input clk,
  input rst_n,
  input start,
  input [4:0] node_count,
  input [15:0] edge_count,
  input [4:0] edges_u [0:15],
  input [4:0] edges_v [0:15],
  output reg [3:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    BUILD_GRAPH,
    FIND_FARTHEST_1,
    FIND_DIA_1,
    FIND_FARTHEST_2,
    FIND_DIA_2,
    CALCULATE_RESULT
  } state_t;

  state_t state, next_state;

  // Adjacency matrix (16x16)
  reg [15:0] adj_matrix [0:15];

  // BFS queue and visited array
  reg [3:0] queue [0:15];
  reg [3:0] queue_head, queue_tail;
  reg [15:0] visited;

  // BFS distance array
  reg [3:0] distance [0:15];

  // BFS current node and max distance tracking
  reg [3:0] current_node, farthest_node, max_distance;

  // Component tracking
  reg [3:0] component1_diameter, component2_diameter;
  reg [3:0] component1_radius, component2_radius;

  // Internal counters
  reg [3:0] edge_idx;
  reg [3:0] node_idx;
  reg [3:0] bfs_step;

  // Initialize state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = BUILD_GRAPH;
      end
      BUILD_GRAPH: begin
        if (edge_idx == edge_count) next_state = FIND_FARTHEST_1;
      end
      FIND_FARTHEST_1: begin
        if (queue_head == queue_tail && bfs_step != 0) next_state = FIND_DIA_1;
      end
      FIND_DIA_1: begin
        if (queue_head == queue_tail && bfs_step != 0) next_state = FIND_FARTHEST_2;
      end
      FIND_FARTHEST_2: begin
        if (queue_head == queue_tail && bfs_step != 0) next_state = FIND_DIA_2;
      end
      FIND_DIA_2: begin
        if (queue_head == queue_tail && bfs_step != 0) next_state = CALCULATE_RESULT;
      end
      CALCULATE_RESULT: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Graph building logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      edge_idx <= 0;
      node_idx <= 0;
      for (int i = 0; i < 16; i++) begin
        adj_matrix[i] <= 0;
      end
    end else if (state == BUILD_GRAPH && edge_idx < edge_count) begin
      reg [4:0] u = edges_u[edge_idx];
      reg [4:0] v = edges_v[edge_idx];
      adj_matrix[u][v] <= 1;
      adj_matrix[v][u] <= 1;
      edge_idx <= edge_idx + 1;
    end
  end

  // BFS initialization and execution
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      queue_head <= 0;
      queue_tail <= 0;
      visited <= 0;
      for (int i = 0; i < 16; i++) begin
        distance[i] <= 0;
      end
      current_node <= 0;
      farthest_node <= 0;
      max_distance <= 0;
      bfs_step <= 0;
    end else begin
      case (state)
        BUILD_GRAPH: begin
          if (edge_idx == edge_count) begin
            visited <= 0;
            queue_head <= 0;
            queue_tail <= 0;
            for (int i = 0; i < 16; i++) begin
              distance[i] <= 0;
            end
            current_node <= 0;
            farthest_node <= 0;
            max_distance <= 0;
            bfs_step <= 0;
          end
        end
        FIND_FARTHEST_1: begin
          if (bfs_step == 0) begin
            // Initialize BFS from node 0
            queue[queue_tail] <= 0;
            queue_tail <= queue_tail + 1;
            visited[0] <= 1;
            distance[0] <= 0;
            bfs_step <= 1;
          end else if (queue_head < queue_tail) begin
            // Dequeue current node
            current_node <= queue[queue_head];
            queue_head <= queue_head + 1;
            // Explore neighbors
            for (int i = 0; i < 16; i++) begin
              if (adj_matrix[current_node][i] && !visited[i]) begin
                queue[queue_tail] <= i;
                queue_tail <= queue_tail + 1;
                visited[i] <= 1;
                distance[i] <= distance[current_node] + 1;
                if (distance[i] > max_distance) begin
                  max_distance <= distance[i];
                  farthest_node <= i;
                end
              end
            end
          end else begin
            // BFS complete, store farthest node
            current_node <= farthest_node;
            bfs_step <= 0;
          end
        end
        FIND_DIA_1: begin
          if (bfs_step == 0) begin
            // Initialize BFS from farthest_node
            queue[queue_tail] <= farthest_node;
            queue_tail <= queue_tail + 1;
            visited <= 0;
            visited[farthest_node] <= 1;
            distance[farthest_node] <= 0;
            max_distance <= 0;
            bfs_step <= 1;
          end else if (queue_head < queue_tail) begin
            // Dequeue current node
            current_node <= queue[queue_head];
            queue_head <= queue_head + 1;
            // Explore neighbors
            for (int i = 0; i < 16; i++) begin
              if (adj_matrix[current_node][i] && !visited[i]) begin
                queue[queue_tail] <= i;
                queue_tail <= queue_tail + 1;
                visited[i] <= 1;
                distance[i] <= distance[current_node] + 1;
                if (distance[i] > max_distance) begin
                  max_distance <= distance[i];
                  farthest_node <= i;
                end
              end
            end
          end else begin
            // BFS complete, store diameter
            component1_diameter <= max_distance;
            component1_radius <= (max_distance + 1) / 2;
            bfs_step <= 0;
          end
        end
        FIND_FARTHEST_2: begin
          if (bfs_step == 0) begin
            // Find next unvisited node
            node_idx <= 0;
            while (node_idx < node_count && visited[node_idx]) begin
              node_idx <= node_idx + 1;
            end
            if (node_idx < node_count) begin
              queue[queue_tail] <= node_idx;
              queue_tail <= queue_tail + 1;
              visited[node_idx] <= 1;
              distance[node_idx] <= 0;
              max_distance <= 0;
              bfs_step <= 1;
            end
          end else if (queue_head < queue_tail) begin
            // Dequeue current node
            current_node <= queue[queue_head];
            queue_head <= queue_head + 1;
            // Explore neighbors
            for (int i = 0; i < 16; i++) begin
              if (adj_matrix[current_node][i] && !visited[i]) begin
                queue[queue_tail] <= i;
                queue_tail <= queue_tail + 1;
                visited[i] <= 1;
                distance[i] <= distance[current_node] + 1;
                if (distance[i] > max_distance) begin
                  max_distance <= distance[i];
                  farthest_node <= i;
                end
              end
            end
          end else begin
            // BFS complete, store farthest node
            current_node <= farthest_node;
            bfs_step <= 0;
          end
        end
        FIND_DIA_2: begin
          if (bfs_step == 0) begin
            // Initialize BFS from farthest_node
            queue[queue_tail] <= farthest_node;
            queue_tail <= queue_tail + 1;
            visited <= 0;
            visited[farthest_node] <= 1;
            distance[farthest_node] <= 0;
            max_distance <= 0;
            bfs_step <= 1;
          end else if (queue_head < queue_tail) begin
            // Dequeue current node
            current_node <= queue[queue_head];
            queue_head <= queue_head + 1;
            // Explore neighbors
            for (int i = 0; i < 16; i++) begin
              if (adj_matrix[current_node][i] && !visited[i]) begin
                queue[queue_tail] <= i;
                queue_tail <= queue_tail + 1;
                visited[i] <= 1;
                distance[i] <= distance[current_node] + 1;
                if (distance[i] > max_distance) begin
                  max_distance <= distance[i];
                  farthest_node <= i;
                end
              end
            end
          end else begin
            // BFS complete, store diameter
            component2_diameter <= max_distance;
            component2_radius <= (max_distance + 1) / 2;
            bfs_step <= 0;
          end
        end
        CALCULATE_RESULT: begin
          reg [3:0] candidate1 = component1_diameter;
          reg [3:0] candidate2 = component2_diameter;
          reg [3:0] candidate3 = component1_radius + component2_radius + 1;
          reg [3:0] max_candidate = (candidate1 > candidate2) ? candidate1 : candidate2;
          result <= (max_candidate > candidate3) ? max_candidate : candidate3;
          done <= 1;
        end
        default: ;
      endcase
    end
  end

endmodule