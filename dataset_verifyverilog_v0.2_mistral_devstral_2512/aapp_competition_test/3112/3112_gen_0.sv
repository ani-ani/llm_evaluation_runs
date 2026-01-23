module producer_routing (
  input clk,
  input rst_n,
  input start,
  input [2:0] K,
  input [2:0] N,
  input [5:0] M,
  input [2:0] edge_a,
  input [2:0] edge_b,
  input edges_valid,
  input edges_done,
  output reg [2:0] max_producers,
  output reg done
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] LOAD_EDGES = 3'b001;
  localparam [2:0] BUILD_PATHS = 3'b010;
  localparam [2:0] CHECK_COMPATIBILITY = 3'b011;
  localparam [2:0] FIND_MAX_SET = 3'b100;
  localparam [2:0] DONE = 3'b101;

  reg [2:0] state = IDLE;
  reg [5:0] edge_counter = 0;
  reg [2:0] current_producer = 0;
  reg [2:0] current_pair_i = 0;
  reg [2:0] current_pair_j = 0;
  reg [7:0] current_mask = 0;
  reg [7:0] max_mask = 0;

  // Adjacency matrix (8x8 bits)
  reg [7:0] adjacency [0:7];

  // Path lengths (8 producers, 8 junctions)
  reg [2:0] path_length [0:7][0:7];

  // Compatibility matrix (8x8 bits)
  reg [7:0] compatible [0:7];

  // BFS queue and visited
  reg [2:0] queue [0:7];
  reg [2:0] queue_head = 0;
  reg [2:0] queue_tail = 0;
  reg [7:0] visited = 0;

  // Temporary storage for BFS
  reg [2:0] current_node = 0;
  reg [2:0] current_dist = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      edge_counter <= 0;
      current_producer <= 0;
      current_pair_i <= 0;
      current_pair_j <= 0;
      current_mask <= 0;
      max_mask <= 0;
      done <= 0;
      max_producers <= 0;

      // Reset adjacency matrix
      for (int i = 0; i < 8; i++) begin
        adjacency[i] <= 0;
      end

      // Reset path lengths
      for (int i = 0; i < 8; i++) begin
        for (int j = 0; j < 8; j++) begin
          path_length[i][j] <= 0;
        end
      end

      // Reset compatibility matrix
      for (int i = 0; i < 8; i++) begin
        compatible[i] <= 0;
      end

      // Reset BFS structures
      queue_head <= 0;
      queue_tail <= 0;
      visited <= 0;
      current_node <= 0;
      current_dist <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD_EDGES;
            edge_counter <= 0;
          end
        end

        LOAD_EDGES: begin
          if (edges_valid) begin
            // Store edge in adjacency matrix
            adjacency[edge_a][edge_b] <= 1;
            edge_counter <= edge_counter + 1;
          end
          if (edges_done) begin
            state <= BUILD_PATHS;
            current_producer <= 0;
          end
        end

        BUILD_PATHS: begin
          // Initialize BFS for current producer
          if (current_node == 0) begin
            // Reset BFS structures
            queue_head <= 0;
            queue_tail <= 0;
            visited <= 0;
            current_node <= current_producer;
            current_dist <= 0;
            visited[current_producer] <= 1;
            path_length[current_producer][current_producer] <= 0;
          end

          // BFS step
          if (current_node != 0) begin
            // Check all neighbors
            for (int i = 0; i < 8; i++) begin
              if (adjacency[current_node][i] && !visited[i]) begin
                visited[i] <= 1;
                path_length[current_producer][i] <= current_dist + 1;
                queue[queue_tail] <= i;
                queue_tail <= queue_tail + 1;
              end
            end

            // Move to next node in queue
            if (queue_head < queue_tail) begin
              current_node <= queue[queue_head];
              current_dist <= path_length[current_producer][current_node];
              queue_head <= queue_head + 1;
            end else begin
              // BFS complete for this producer
              current_node <= 0;
              current_producer <= current_producer + 1;
              if (current_producer >= K) begin
                state <= CHECK_COMPATIBILITY;
                current_pair_i <= 0;
                current_pair_j <= 0;
              end
            end
          end
        end

        CHECK_COMPATIBILITY: begin
          // Check compatibility for pair (i,j)
          if (current_pair_i < K && current_pair_j < K) begin
            reg [2:0] shared_edge = 0;
            reg [2:0] dist_i = 0;
            reg [2:0] dist_j = 0;
            reg compatible_flag = 1;

            // Check all edges
            for (int a = 0; a < 8; a++) begin
              for (int b = 0; b < 8; b++) begin
                if (adjacency[a][b]) begin
                  // Check if both producers use this edge
                  if (path_length[current_pair_i][a] != 0 && 
                      path_length[current_pair_i][b] != 0 &&
                      path_length[current_pair_j][a] != 0 &&
                      path_length[current_pair_j][b] != 0) begin
                    shared_edge <= 1;
                    dist_i <= path_length[current_pair_i][a];
                    dist_j <= path_length[current_pair_j][a];
                    if ((dist_j - dist_i) % 2 == 0) begin
                      compatible_flag <= 0;
                    end
                  end
                end
              end
            end

            // If no shared edges, they are compatible
            if (!shared_edge) begin
              compatible_flag <= 1;
            end

            compatible[current_pair_i][current_pair_j] <= compatible_flag;
            compatible[current_pair_j][current_pair_i] <= compatible_flag;

            // Move to next pair
            current_pair_j <= current_pair_j + 1;
            if (current_pair_j >= K) begin
              current_pair_j <= 0;
              current_pair_i <= current_pair_i + 1;
              if (current_pair_i >= K) begin
                state <= FIND_MAX_SET;
                current_mask <= 0;
                max_mask <= 0;
              end
            end
          end
        end

        FIND_MAX_SET: begin
          // Brute force check all possible subsets
          reg [7:0] next_mask = current_mask + 1;
          reg [2:0] count = 0;
          reg valid = 1;

          // Check if current mask is valid
          for (int i = 0; i < 8; i++) begin
            if (current_mask[i]) begin
              count <= count + 1;
              for (int j = i+1; j < 8; j++) begin
                if (current_mask[j] && !compatible[i][j]) begin
                  valid <= 0;
                end
              end
            end
          end

          // Update max if valid and larger
          if (valid && (count > $clog2(max_mask + 1))) begin
            max_mask <= current_mask;
          end

          // Move to next mask
          current_mask <= next_mask;
          if (next_mask == 0) begin
            state <= DONE;
            done <= 1;
            max_producers <= $clog2(max_mask + 1);
          end
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule