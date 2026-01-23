module shortest_path_edge_counter (
  input clk,
  input rst_n,
  input start,
  input [3:0] node_count,
  input [3:0] edge_count,
  input [3:0] edge_src [15:0],
  input [3:0] edge_dst [15:0],
  input [7:0] edge_weight [15:0],
  output reg [31:0] edge_usage [15:0],
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    LOAD_EDGES,
    COMPUTE_DISTANCES,
    COUNT_PATHS,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] dist [7:0][7:0]; // Distance matrix (8x8)
  reg [31:0] paths [7:0][7:0]; // Path count matrix (8x8)
  reg [31:0] temp_paths [7:0][7:0]; // Temporary path count matrix

  reg [3:0] i, j, k; // Loop counters
  reg [3:0] e; // Edge counter
  reg [3:0] u, v; // Node counters for path counting
  reg [3:0] a, b; // Edge endpoints
  reg [7:0] weight; // Edge weight
  reg [31:0] count; // Temporary count

  reg [31:0] cycle_counter; // Cycle counter for latency

  // Initialize all outputs
  integer idx;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      for (idx = 0; idx < 16; idx = idx + 1) begin
        edge_usage[idx] <= 0;
      end
    end
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      cycle_counter <= 0;
      // Initialize distance matrix
      for (i = 0; i < 8; i = i + 1) begin
        for (j = 0; j < 8; j = j + 1) begin
          dist[i][j] <= 255; // Infinity
        end
        dist[i][i] <= 0; // Distance to self is 0
      end
      // Initialize path counts
      for (i = 0; i < 8; i = i + 1) begin
        for (j = 0; j < 8; j = j + 1) begin
          paths[i][j] <= 0;
          temp_paths[i][j] <= 0;
        end
        paths[i][i] <= 1; // One path to self
        temp_paths[i][i] <= 1;
      end
      // Reset counters
      i <= 0;
      j <= 0;
      k <= 0;
      e <= 0;
      u <= 0;
      v <= 0;
      a <= 0;
      b <= 0;
      weight <= 0;
      count <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = LOAD_EDGES;
          cycle_counter = 0;
        end
      end

      LOAD_EDGES: begin
        if (e < edge_count) begin
          // Load edge into distance matrix
          a = edge_src[e];
          b = edge_dst[e];
          weight = edge_weight[e];
          dist[a][b] = weight;
          e = e + 1;
        end else begin
          next_state = COMPUTE_DISTANCES;
          e = 0;
          i = 0;
          j = 0;
          k = 0;
        end
      end

      COMPUTE_DISTANCES: begin
        // Floyd-Warshall algorithm
        if (k < node_count) begin
          if (i < node_count) begin
            if (j < node_count) begin
              // Check if path through k is shorter
              if (dist[i][k] + dist[k][j] < dist[i][j]) begin
                dist[i][j] = dist[i][k] + dist[k][j];
                paths[i][j] = paths[i][k] * paths[k][j];
              end else if (dist[i][k] + dist[k][j] == dist[i][j]) begin
                paths[i][j] = paths[i][j] + paths[i][k] * paths[k][j];
              end
              j = j + 1;
            end else begin
              j = 0;
              i = i + 1;
            end
          end else begin
            i = 0;
            k = k + 1;
          end
        end else begin
          next_state = COUNT_PATHS;
          k = 0;
          i = 0;
          j = 0;
          e = 0;
          u = 0;
          v = 0;
        end
      end

      COUNT_PATHS: begin
        if (e < edge_count) begin
          a = edge_src[e];
          b = edge_dst[e];
          weight = edge_weight[e];

          if (u < node_count) begin
            if (v < node_count) begin
              // Check if edge (a,b) is on a shortest path from u to v
              if (dist[u][a] + weight + dist[b][v] == dist[u][v]) begin
                count = count + paths[u][a] * paths[b][v];
              end
              v = v + 1;
            end else begin
              v = 0;
              u = u + 1;
            end
          end else begin
            edge_usage[e] = count;
            count = 0;
            u = 0;
            v = 0;
            e = e + 1;
          end
        end else begin
          next_state = DONE;
          done = 1;
        end
      end

      DONE: begin
        if (cycle_counter >= 300) begin
          next_state = IDLE;
          done = 0;
        end else begin
          cycle_counter = cycle_counter + 1;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule