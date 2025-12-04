module book_presentations(
  input clk,
  input rst_n,
  input start,
  input [15:0] bipartite_graph,
  output reg [2:0] max_matching,
  output reg done
);

  typedef enum logic [3:0] {
    IDLE,
    INIT,
    BFS_SETUP,
    BFS_EXECUTE,
    DFS_SETUP,
    DFS_EXECUTE,
    UPDATE_MATCH,
    COMPLETE
  } state_t;

  state_t state;
  reg [3:0] cycle_count;
  reg [1:0] boy_match [0:3];
  reg [1:0] girl_match [0:3];
  reg [3:0] bfs_queue;
  reg [1:0] bfs_dist [0:3];
  reg [3:0] free_boys;
  reg [3:0] adj_matrix [0:3];
  reg [3:0] dfs_candidate;
  reg found_path;
  reg [2:0] match_count;

  always_comb begin
    match_count = (boy_match[0] != 2'b11) + (boy_match[1] != 2'b11) +
                  (boy_match[2] != 2'b11) + (boy_match[3] != 2'b11);
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      max_matching <= 3'b0;
      cycle_count <= 4'b0;
      for (int i=0; i<4; i++) begin
        boy_match[i] <= 2'b11;
        girl_match[i] <= 2'b11;
        bfs_dist[i] <= 2'd0;
        adj_matrix[i] <= 4'b0;
      end
      bfs_queue <= 4'b0;
      free_boys <= 4'b0;
      dfs_candidate <= 4'b0;
      found_path <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= INIT;
          end
        end

        INIT: begin
          for (int i=0; i<4; i++) begin
            boy_match[i] <= 2'b11;
            girl_match[i] <= 2'b11;
            adj_matrix[i] <= bipartite_graph[i*4 +: 4];
            bfs_dist[i] <= 2'd3;
          end
          max_matching <= 3'b0;
          cycle_count <= 4'b0;
          state <= BFS_SETUP;
        end

        BFS_SETUP: begin
          free_boys <= {boy_match[3] == 2'b11, boy_match[2] == 2'b11,
                       boy_match[1] == 2'b11, boy_match[0] == 2'b11};
          bfs_queue <= free_boys;
          for (int i=0; i<4; i++) begin
            bfs_dist[i] <= free_boys[i] ? 2'd0 : 2'd3;
          end
          found_path <= 1'b0;
          state <= BFS_EXECUTE;
          cycle_count <= cycle_count + 1;
        end

        BFS_EXECUTE: begin
          if (|bfs_queue) begin
            for (int b=0; b<4; b++) begin
              if (bfs_queue[b]) begin
                for (int g=0; g<4; g++) begin
                  if (adj_matrix[b][g] && bfs_dist[boy_match[g]] == 2'd3) begin
                    bfs_dist[boy_match[g]] <= bfs_dist[b] + 1;
                    bfs_queue[boy_match[g]] <= 1'b1;
                    if (girl_match[g] == 2'b11) found_path <= 1'b1;
                  end
                end
              end
            end
          end
          state <= DFS_SETUP;
          cycle_count <= cycle_count + 1;
        end

        DFS_SETUP: begin
          dfs_candidate <= free_boys;
          state <= DFS_EXECUTE;
          cycle_count <= cycle_count + 1;
        end

        DFS_EXECUTE: begin
          for (int b=0; b<4; b++) begin
            if (dfs_candidate[b]) begin
              for (int g=0; g<4; g++) begin
                if (adj_matrix[b][g] && bfs_dist[boy_match[g]] == bfs_dist[b] + 1) begin
                  if (girl_match[g] == 2'b11 || dfs_candidate[boy_match[g]]) begin
                    boy_match[b] <= g;
                    girl_match[g] <= b;
                    dfs_candidate[boy_match[g]] <= 1'b1;
                    dfs_candidate[b] <= 1'b0;
                    found_path <= 1'b1;
                  end
                end
              end
            end
          end
          cycle_count <= cycle_count + 1;
          if (cycle_count < 15 && found_path) begin
            state <= BFS_SETUP;
          end else begin
            state <= UPDATE_MATCH;
          end
        end

        UPDATE_MATCH: begin
          max_matching <= match_count;
          state <= COMPLETE;
          cycle_count <= cycle_count + 1;
        end

        COMPLETE: begin
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule