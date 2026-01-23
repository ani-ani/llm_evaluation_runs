module min_trucks_solver (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_nodes,
  input [2:0] num_edges,
  input [2:0] num_clients,
  input [2:0] client_locs [3:0],
  input [2:0] edge_u [7:0],
  input [2:0] edge_v [7:0],
  input [3:0] edge_w [7:0],
  output reg [2:0] min_trucks,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    BUILD_DIST,
    BUILD_DAG,
    COMPUTE_RESULT,
    DONE
  } state_t;

  state_t state;
  reg [2:0] cycle_count;
  reg [3:0] dist [7:0];
  reg [3:0] new_dist [7:0];
  reg [7:0] dag_edges [7:0];
  reg [2:0] dp [15:0];
  reg [2:0] i, j, k;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_count <= 0;
      min_trucks <= 0;
      done <= 0;
      for (i = 0; i < 8; i = i + 1) begin
        dist[i] <= 16'hFFFF;
        new_dist[i] <= 16'hFFFF;
        dag_edges[i] <= 0;
      end
      for (i = 0; i < 16; i = i + 1) begin
        dp[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= BUILD_DIST;
            cycle_count <= 0;
            dist[0] <= 0;
            for (i = 1; i < 8; i = i + 1) begin
              dist[i] <= 16'hFFFF;
            end
          end
        end

        BUILD_DIST: begin
          // Initialize new_dist
          for (i = 0; i < 8; i = i + 1) begin
            new_dist[i] <= dist[i];
          end

          // Relax edges
          for (i = 0; i < num_edges; i = i + 1) begin
            if (dist[edge_u[i]] + edge_w[i] < new_dist[edge_v[i]]) begin
              new_dist[edge_v[i]] <= dist[edge_u[i]] + edge_w[i];
            end
          end

          // Update distances
          for (i = 0; i < 8; i = i + 1) begin
            dist[i] <= new_dist[i];
          end

          cycle_count <= cycle_count + 1;
          if (cycle_count == 7) begin
            state <= BUILD_DAG;
            cycle_count <= 0;
          end
        end

        BUILD_DAG: begin
          // Clear DAG edges
          for (i = 0; i < 8; i = i + 1) begin
            dag_edges[i] <= 0;
          end

          // Build DAG
          for (i = 0; i < num_edges; i = i + 1) begin
            if (dist[edge_u[i]] + edge_w[i] == dist[edge_v[i]]) begin
              dag_edges[edge_u[i]] <= dag_edges[edge_u[i]] | (1 << edge_v[i]);
            end
          end

          state <= COMPUTE_RESULT;
        end

        COMPUTE_RESULT: begin
          // Initialize DP table
          for (i = 0; i < 16; i = i + 1) begin
            dp[i] <= 0;
          end

          // DP computation for minimum path cover
          for (i = 0; i < num_clients; i = i + 1) begin
            dp[1 << i] <= 1;
          end

          for (i = 1; i < (1 << num_clients); i = i + 1) begin
            if (dp[i] == 0) begin
              dp[i] <= 8;
              for (j = 0; j < num_clients; j = j + 1) begin
                if (i & (1 << j)) begin
                  for (k = 0; k < num_clients; k = k + 1) begin
                    if (j != k && (i & (1 << k)) && (dag_edges[client_locs[j]] & (1 << client_locs[k]))) begin
                      if (dp[i ^ (1 << j)] + 1 < dp[i]) begin
                        dp[i] <= dp[i ^ (1 << j)] + 1;
                      end
                    end
                  end
                end
              end
            end
          end

          min_trucks <= dp[(1 << num_clients) - 1];
          state <= DONE;
        end

        DONE: begin
          done <= 1;
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