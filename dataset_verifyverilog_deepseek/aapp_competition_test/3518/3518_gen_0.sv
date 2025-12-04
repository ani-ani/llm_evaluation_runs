module min_co2_matcher (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] m,
  input [2:0] p [0:27],
  input [2:0] q [0:27],
  input [13:0] c [0:27],
  output reg [15:0] min_co2,
  output reg impossible,
  output reg done
);

  typedef enum logic [2:0] {IDLE, INIT, BUILD_ADJ, CHECK_EDGES, FIND_MATCHING, CALC_SUM, FINISH} state_t;
  state_t state, next_state;

  reg [13:0] adj [0:7][0:7];
  reg [7:0] paired;
  reg [2:0] student_idx;
  reg [15:0] current_sum, min_sum;
  reg [2:0] pair_count;
  reg [3:0] edge_idx;
  reg invalid_graph;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      impossible <= 0;
      min_co2 <= 16'hFFFF;
      current_sum <= 0;
      min_sum <= 16'hFFFF;
      paired <= 0;
      student_idx <= 0;
      edge_idx <= 0;
      invalid_graph <= 0;
      pair_count <= 0;
      for (int i = 0; i < 8; i++) for (int j = 0; j < 8; j++) adj[i][j] <= 14'h3FFF;
    end
    else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
            done <= 0;
            impossible <= 0;
            min_sum <= 16'hFFFF;
          end
        end

        INIT: begin
          if (n == 0 || n[0]) begin // Check if n is odd or zero
            impossible <= 1;
            done <= 1;
            state <= IDLE;
          end
          else begin
            edge_idx <= 0;
            state <= BUILD_ADJ;
          end
        end

        BUILD_ADJ: begin
          if (edge_idx < m) begin
            adj[p[edge_idx]][q[edge_idx]] <= c[edge_idx];
            adj[q[edge_idx]][p[edge_idx]] <= c[edge_idx];
            edge_idx <= edge_idx + 1;
          end
          else begin
            state <= CHECK_EDGES;
            student_idx <= 0;
            invalid_graph <= 0;
          end
        end

        CHECK_EDGES: begin
          if (student_idx < n) begin
            for (int j = student_idx+1; j < n; j++) begin
              if (adj[student_idx][j] == 14'h3FFF) invalid_graph <= 1;
            end
            student_idx <= student_idx + 1;
          end
          else begin
            if (invalid_graph) begin
              impossible <= 1;
              done <= 1;
              state <= IDLE;
            end
            else begin
              state <= FIND_MATCHING;
              paired <= 8'b00000001; // Mark student 0 as paired first
              current_sum <= 0;
              pair_count <= 1;
              student_idx <= 1;
            end
          end
        end

        FIND_MATCHING: begin
          if (!paired[student_idx] && student_idx < n) begin
            for (int i = 0; i < student_idx; i++) begin
              if (!paired[i]) begin
                paired[i] <= 1;
                paired[student_idx] <= 1;
                current_sum <= current_sum + adj[i][student_idx];
                pair_count <= pair_count + 1;
                break;
              end
            end
            student_idx <= student_idx + 1;
          end
          else if (pair_count == (n >> 1)) begin // All paired
            state <= CALC_SUM;
          end
          else if (student_idx >= n) begin
            student_idx <= 0;
          end
          else begin
            student_idx <= student_idx + 1;
          end
        end

        CALC_SUM: begin
          if (current_sum < min_sum) begin
            min_sum <= current_sum;
          end
          impossible <= 0;
          state <= FINISH;
        end

        FINISH: begin
          min_co2 <= min_sum;
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule