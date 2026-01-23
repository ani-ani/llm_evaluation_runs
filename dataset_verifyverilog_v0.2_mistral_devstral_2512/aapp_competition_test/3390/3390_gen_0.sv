module longest_menu (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_nodes,
  input [7:0][7:0] adjacency_matrix,
  output reg [3:0] result,
  output reg done
);

  // States
  typedef enum logic [2:0] {
    IDLE,
    INIT,
    K_LOOP,
    I_LOOP,
    J_LOOP,
    FIND_MAX,
    DONE
  } state_t;

  state_t state;
  reg [2:0] k, i, j;
  reg [3:0] dist [0:7][0:7];
  reg [3:0] max_val;
  reg [5:0] cycle_count;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      k <= 0;
      i <= 0;
      j <= 0;
      max_val <= 0;
      cycle_count <= 0;
      done <= 0;
      result <= 0;
      for (int x = 0; x < 8; x++) begin
        for (int y = 0; y < 8; y++) begin
          dist[x][y] <= 0;
        end
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
            cycle_count <= 0;
          end
        end

        INIT: begin
          // Initialize distance matrix
          for (int x = 0; x < 8; x++) begin
            dist[x][x] <= 1;
            for (int y = 0; y < 8; y++) begin
              if (adjacency_matrix[x][y]) begin
                dist[x][y] <= 2;
              end
            end
          end
          state <= K_LOOP;
          k <= 0;
          i <= 0;
          j <= 0;
        end

        K_LOOP: begin
          if (k < num_nodes) begin
            state <= I_LOOP;
            i <= 0;
          end else begin
            state <= FIND_MAX;
          end
        end

        I_LOOP: begin
          if (i < num_nodes) begin
            state <= J_LOOP;
            j <= 0;
          end else begin
            k <= k + 1;
            state <= K_LOOP;
          end
        end

        J_LOOP: begin
          if (j < num_nodes) begin
            // Floyd-Warshall update
            if (dist[i][k] > 0 && dist[k][j] > 0) begin
              if (dist[i][k] + dist[k][j] - 1 > dist[i][j]) begin
                dist[i][j] <= dist[i][k] + dist[k][j] - 1;
              end
            end
            j <= j + 1;
            cycle_count <= cycle_count + 1;
          end else begin
            i <= i + 1;
            state <= I_LOOP;
          end
        end

        FIND_MAX: begin
          max_val <= 0;
          for (int x = 0; x < 8; x++) begin
            for (int y = 0; y < 8; y++) begin
              if (dist[x][y] > max_val) begin
                max_val <= dist[x][y];
              end
            end
          end
          result <= max_val;
          done <= 1;
          state <= DONE;
        end

        DONE: begin
          if (!start) begin
            done <= 0;
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule