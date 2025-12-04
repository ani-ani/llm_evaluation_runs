module minimal_settlers(
  input clk,
  input rst_n,
  input start,
  input [3:0] node_count,
  input [3:0] iron_count,
  input [3:0] coal_count,
  input [7:0] iron_list,
  input [7:0] coal_list,
  input [7:0][3:0] neighbor_counts,
  input [7:0][3:0][2:0] neighbors,
  output reg [3:0] result,
  output reg done,
  output reg impossible
);

  enum logic [2:0] {IDLE, IRON_BFS, COAL_BFS, CALCULATE, DONE} state, next_state;

  reg [7:0] iron_visited, coal_visited;
  reg [3:0] iron_dist [0:7];
  reg [3:0] coal_dist [0:7];
  reg [2:0] bfs_queue [0:7];
  reg [3:0] q_head, q_tail;
  reg [3:0] min_iron, min_coal;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      impossible <= 0;
      result <= 0;
      iron_visited <= 8'b0;
      coal_visited <= 8'b0;
      for (int i = 0; i < 8; i++) begin
        iron_dist[i] <= 4'b1111;
        coal_dist[i] <= 4'b1111;
      end
      q_head <= 0;
      q_tail <= 0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          if (start) begin
            iron_visited <= 8'b00000001;
            coal_visited <= 8'b0;
            iron_dist[0] <= 0;
            coal_dist[0] <= 4'b1111;
            bfs_queue[0] <= 0;
            q_head <= 0;
            q_tail <= 1;
          end
        end

        IRON_BFS: begin
          if (q_head != q_tail) begin
            automatic logic [2:0] curr_node = bfs_queue[q_head];
            automatic logic [3:0] n_count = neighbor_counts[curr_node];
            q_head <= q_head + 1;

            for (int j = 0; j < 4; j++) begin
              if (j < n_count) begin
                automatic logic [2:0] neighbor = neighbors[curr_node][j];
                if (!iron_visited[neighbor]) begin
                  iron_visited[neighbor] <= 1'b1;
                  iron_dist[neighbor] <= iron_dist[curr_node] + 1;
                  bfs_queue[q_tail] <= neighbor;
                  q_tail <= q_tail + 1;
                end
              end
            end
          end
        end

        COAL_BFS: begin
          if (q_head != q_tail) begin
            automatic logic [2:0] curr_node = bfs_queue[q_head];
            automatic logic [3:0] n_count = neighbor_counts[curr_node];
            q_head <= q_head + 1;

            for (int j = 0; j < 4; j++) begin
              if (j < n_count) begin
                automatic logic [2:0] neighbor = neighbors[curr_node][j];
                if (!coal_visited[neighbor]) begin
                  coal_visited[neighbor] <= 1'b1;
                  coal_dist[neighbor] <= coal_dist[curr_node] + 1;
                  bfs_queue[q_tail] <= neighbor;
                  q_tail <= q_tail + 1;
                end
              end
            end
          end
        end

        CALCULATE: begin
          min_iron <= 4'b1111;
          min_coal <= 4'b1111;

          for (int i = 0; i < 8; i++) begin
            if (iron_visited[i] && iron_list[i] && (iron_dist[i] < min_iron))
              min_iron <= iron_dist[i];
            if (coal_visited[i] && coal_list[i] && (coal_dist[i] < min_coal))
              min_coal <= coal_dist[i];
          end

          if (min_iron != 4'b1111 && min_coal != 4'b1111) begin
            impossible <= 0;
            result <= min_iron + min_coal - 4'd1;
          end else
            impossible <= 1;
        end

        DONE: done <= 1'b1;

        default: begin
          done <= 1'b0;
          impossible <= 1'b0;
        end
      endcase

      if (state == IRON_BFS && q_head == q_tail) begin
        coal_visited <= 8'b00000001;
        coal_dist[0] <= 0;
        bfs_queue[0] <= 0;
        q_head <= 0;
        q_tail <= 1;
      end
    end
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE: if (start) next_state = IRON_BFS;
      IRON_BFS: if (q_head == q_tail) next_state = COAL_BFS;
      COAL_BFS: if (q_head == q_tail) next_state = CALCULATE;
      CALCULATE: next_state = DONE;
      DONE: next_state = IDLE;
    endcase
  end

endmodule