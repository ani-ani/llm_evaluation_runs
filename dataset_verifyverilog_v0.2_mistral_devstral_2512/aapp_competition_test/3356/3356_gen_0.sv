module mole_residence (
  input clk,
  input rst_n,
  input start,
  input [2:0] node_a_i,
  input [2:0] node_b_i,
  input input_valid,
  input input_done,
  output reg [7:0] diameter_result,
  output reg [2:0] close_node_a,
  output reg [2:0] close_node_b,
  output reg [2:0] open_node_a,
  output reg [2:0] open_node_b,
  output reg computation_done
);

  // Constants
  localparam IDLE = 3'b000;
  localparam INPUT_EDGES = 3'b001;
  localparam INIT_BFS = 3'b010;
  localparam BFS_DEPTH_1 = 3'b011;
  localparam BFS_DEPTH_2 = 3'b100;
  localparam BFS_DEPTH_3 = 3'b101;
  localparam BFS_DEPTH_4 = 3'b110;
  localparam BFS_DEPTH_5 = 3'b111;
  localparam FIND_DIA_END = 3'b000; // Reuse state encoding
  localparam TRACE_PATH = 3'b001; // Reuse state encoding
  localparam ANALYZE_PATH = 3'b010; // Reuse state encoding
  localparam RECONNECT = 3'b011; // Reuse state encoding
  localparam DONE = 3'b100; // Reuse state encoding

  // State machine
  reg [2:0] state = IDLE;

  // Adjacency matrix (8x8)
  reg [7:0] adj_matrix [0:7];
  reg [2:0] edge_count = 0;

  // BFS variables
  reg [2:0] bfs_start_node = 0;
  reg [2:0] bfs_current_node = 0;
  reg [2:0] bfs_queue [0:7];
  reg [2:0] bfs_queue_ptr = 0;
  reg [2:0] bfs_queue_size = 0;
  reg [2:0] distance [0:7];
  reg [2:0] parent [0:7];

  // Diameter variables
  reg [2:0] dia_start = 0;
  reg [2:0] dia_end = 0;
  reg [2:0] dia_max_dist = 0;

  // Path tracing
  reg [2:0] path [0:7];
  reg [2:0] path_length = 0;

  // Center and leaf
  reg [2:0] center_node = 0;
  reg [2:0] leaf_node = 0;
  reg [2:0] leaf_parent = 0;

  // Initialize adjacency matrix
  integer i, j;
  initial begin
    for (i = 0; i < 8; i = i + 1) begin
      adj_matrix[i] = 8'b0;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      edge_count <= 0;
      bfs_queue_ptr <= 0;
      bfs_queue_size <= 0;
      dia_max_dist <= 0;
      path_length <= 0;
      computation_done <= 0;
      diameter_result <= 0;
      close_node_a <= 0;
      close_node_b <= 0;
      open_node_a <= 0;
      open_node_b <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INPUT_EDGES;
          end
        end

        INPUT_EDGES: begin
          if (input_valid) begin
            // Store edge in adjacency matrix (1-based to 0-based)
            adj_matrix[node_a_i - 1][node_b_i - 1] <= 1'b1;
            adj_matrix[node_b_i - 1][node_a_i - 1] <= 1'b1;
            edge_count <= edge_count + 1;
          end
          if (input_done) begin
            state <= INIT_BFS;
          end
        end

        INIT_BFS: begin
          // Initialize BFS from node 0 (1-based node 1)
          bfs_start_node <= 0;
          bfs_current_node <= 0;
          bfs_queue[0] <= 0;
          bfs_queue_ptr <= 0;
          bfs_queue_size <= 1;
          for (i = 0; i < 8; i = i + 1) begin
            distance[i] <= 8'b0;
            parent[i] <= 8'b0;
          end
          distance[0] <= 0;
          parent[0] <= 0;
          state <= BFS_DEPTH_1;
        end

        BFS_DEPTH_1: begin
          // Process current node
          for (i = 0; i < 8; i = i + 1) begin
            if (adj_matrix[bfs_current_node][i] && distance[i] == 0 && i != bfs_current_node) begin
              distance[i] <= distance[bfs_current_node] + 1;
              parent[i] <= bfs_current_node;
              bfs_queue[bfs_queue_size] <= i;
              bfs_queue_size <= bfs_queue_size + 1;
            end
          end
          bfs_queue_ptr <= bfs_queue_ptr + 1;
          if (bfs_queue_ptr < bfs_queue_size) begin
            bfs_current_node <= bfs_queue[bfs_queue_ptr];
          end else begin
            state <= BFS_DEPTH_2;
          end
        end

        BFS_DEPTH_2: begin
          // Continue BFS
          if (bfs_queue_ptr < bfs_queue_size) begin
            bfs_current_node <= bfs_queue[bfs_queue_ptr];
            for (i = 0; i < 8; i = i + 1) begin
              if (adj_matrix[bfs_current_node][i] && distance[i] == 0 && i != bfs_current_node) begin
                distance[i] <= distance[bfs_current_node] + 1;
                parent[i] <= bfs_current_node;
                bfs_queue[bfs_queue_size] <= i;
                bfs_queue_size <= bfs_queue_size + 1;
              end
            end
            bfs_queue_ptr <= bfs_queue_ptr + 1;
          end else begin
            state <= BFS_DEPTH_3;
          end
        end

        BFS_DEPTH_3: begin
          // Continue BFS
          if (bfs_queue_ptr < bfs_queue_size) begin
            bfs_current_node <= bfs_queue[bfs_queue_ptr];
            for (i = 0; i < 8; i = i + 1) begin
              if (adj_matrix[bfs_current_node][i] && distance[i] == 0 && i != bfs_current_node) begin
                distance[i] <= distance[bfs_current_node] + 1;
                parent[i] <= bfs_current_node;
                bfs_queue[bfs_queue_size] <= i;
                bfs_queue_size <= bfs_queue_size + 1;
              end
            end
            bfs_queue_ptr <= bfs_queue_ptr + 1;
          end else begin
            state <= BFS_DEPTH_4;
          end
        end

        BFS_DEPTH_4: begin
          // Continue BFS
          if (bfs_queue_ptr < bfs_queue_size) begin
            bfs_current_node <= bfs_queue[bfs_queue_ptr];
            for (i = 0; i < 8; i = i + 1) begin
              if (adj_matrix[bfs_current_node][i] && distance[i] == 0 && i != bfs_current_node) begin
                distance[i] <= distance[bfs_current_node] + 1;
                parent[i] <= bfs_current_node;
                bfs_queue[bfs_queue_size] <= i;
                bfs_queue_size <= bfs_queue_size + 1;
              end
            end
            bfs_queue_ptr <= bfs_queue_ptr + 1;
          end else begin
            state <= BFS_DEPTH_5;
          end
        end

        BFS_DEPTH_5: begin
          // Continue BFS
          if (bfs_queue_ptr < bfs_queue_size) begin
            bfs_current_node <= bfs_queue[bfs_queue_ptr];
            for (i = 0; i < 8; i = i + 1) begin
              if (adj_matrix[bfs_current_node][i] && distance[i] == 0 && i != bfs_current_node) begin
                distance[i] <= distance[bfs_current_node] + 1;
                parent[i] <= bfs_current_node;
                bfs_queue[bfs_queue_size] <= i;
                bfs_queue_size <= bfs_queue_size + 1;
              end
            end
            bfs_queue_ptr <= bfs_queue_ptr + 1;
          end else begin
            state <= FIND_DIA_END;
          end
        end

        FIND_DIA_END: begin
          // Find furthest node from start
          dia_max_dist <= 0;
          dia_end <= 0;
          for (i = 0; i < 8; i = i + 1) begin
            if (distance[i] > dia_max_dist) begin
              dia_max_dist <= distance[i];
              dia_end <= i;
            end
          end
          state <= TRACE_PATH;
        end

        TRACE_PATH: begin
          // Trace path from dia_end to dia_start
          path_length <= 0;
          path[path_length] <= dia_end;
          path_length <= path_length + 1;
          bfs_current_node <= dia_end;
          while (bfs_current_node != bfs_start_node) begin
            bfs_current_node <= parent[bfs_current_node];
            path[path_length] <= bfs_current_node;
            path_length <= path_length + 1;
          end
          state <= ANALYZE_PATH;
        end

        ANALYZE_PATH: begin
          // Identify center and leaf
          center_node <= path[path_length / 2];
          leaf_node <= path[path_length - 1];
          leaf_parent <= path[path_length - 2];
          state <= RECONNECT;
        end

        RECONNECT: begin
          // Output results
          diameter_result <= dia_max_dist;
          close_node_a <= leaf_parent + 1;
          close_node_b <= leaf_node + 1;
          open_node_a <= leaf_node + 1;
          open_node_b <= center_node + 1;
          computation_done <= 1'b1;
          state <= DONE;
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            computation_done <= 1'b0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule