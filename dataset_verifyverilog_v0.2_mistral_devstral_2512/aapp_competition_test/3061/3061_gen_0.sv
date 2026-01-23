module graph_race_solver (
  input clk,
  input rst_n,
  input start,
  input [7:0] adj_matrix_flat,
  output reg [7:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    LOAD_MATRIX,
    COMPUTE_FW,
    COMPUTE_BW,
    EVAL_EDGES,
    DONE
  } state_t;

  state_t state;
  reg [2:0] cycle_count;
  reg [7:0] adj_matrix [0:7][0:7];
  reg [7:0] forward_dist [0:7];
  reg [7:0] backward_dist [0:7];
  reg [7:0] max_global;
  reg [7:0] min_result;
  reg [7:0] current_edge_u;
  reg [7:0] current_edge_v;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_count <= 0;
      result <= 0;
      done <= 0;
      for (int i = 0; i < 8; i++) begin
        for (int j = 0; j < 8; j++) begin
          adj_matrix[i][j] <= 0;
        end
        forward_dist[i] <= 0;
        backward_dist[i] <= 0;
      end
      max_global <= 0;
      min_result <= 0;
      current_edge_u <= 0;
      current_edge_v <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD_MATRIX;
            cycle_count <= 0;
          end
        end

        LOAD_MATRIX: begin
          adj_matrix[cycle_count][7:0] <= adj_matrix_flat;
          cycle_count <= cycle_count + 1;
          if (cycle_count == 7) begin
            state <= COMPUTE_FW;
            cycle_count <= 0;
          end
        end

        COMPUTE_FW: begin
          // Initialize forward_dist
          if (cycle_count == 0) begin
            for (int i = 0; i < 8; i++) begin
              forward_dist[i] <= 0;
            end
          end

          // Update forward_dist
          for (int i = 0; i < 8; i++) begin
            for (int j = 0; j < 8; j++) begin
              if (adj_matrix[i][j]) begin
                if (forward_dist[j] < forward_dist[i] + 1) begin
                  forward_dist[j] <= forward_dist[i] + 1;
                end
              end
            end
          end

          cycle_count <= cycle_count + 1;
          if (cycle_count == 7) begin
            state <= COMPUTE_BW;
            cycle_count <= 0;
          end
        end

        COMPUTE_BW: begin
          // Initialize backward_dist
          if (cycle_count == 0) begin
            for (int i = 0; i < 8; i++) begin
              backward_dist[i] <= 0;
            end
          end

          // Update backward_dist
          for (int i = 0; i < 8; i++) begin
            for (int j = 0; j < 8; j++) begin
              if (adj_matrix[j][i]) begin
                if (backward_dist[j] < backward_dist[i] + 1) begin
                  backward_dist[j] <= backward_dist[i] + 1;
                end
              end
            end
          end

          cycle_count <= cycle_count + 1;
          if (cycle_count == 7) begin
            state <= EVAL_EDGES;
            cycle_count <= 0;
            max_global <= 0;
            for (int i = 0; i < 8; i++) begin
              if (forward_dist[i] > max_global) begin
                max_global <= forward_dist[i];
              end
            end
            min_result <= max_global;
            current_edge_u <= 0;
            current_edge_v <= 0;
          end
        end

        EVAL_EDGES: begin
          if (adj_matrix[current_edge_u][current_edge_v]) begin
            reg [7:0] path_len;
            path_len = backward_dist[current_edge_u] + 1 + forward_dist[current_edge_v];
            if (path_len == max_global) begin
              reg [7:0] new_len;
              new_len = (backward_dist[current_edge_u] > forward_dist[current_edge_v]) ? backward_dist[current_edge_u] : forward_dist[current_edge_v];
              if (new_len < min_result) begin
                min_result <= new_len;
              end
            end
          end

          current_edge_v <= current_edge_v + 1;
          if (current_edge_v == 8) begin
            current_edge_v <= 0;
            current_edge_u <= current_edge_u + 1;
            if (current_edge_u == 8) begin
              state <= DONE;
              result <= min_result;
              done <= 1;
            end
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