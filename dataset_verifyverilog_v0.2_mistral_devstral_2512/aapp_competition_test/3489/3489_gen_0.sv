module safe_network (
  input clk,
  input rst_n,
  input start,
  input [3:0] n_minus_1_edges_count,
  input [3:0] edge_index,
  input [3:0] u,
  input [3:0] v,
  input [3:0] h,
  output reg [3:0] m,
  output reg [3:0] out_u,
  output reg [3:0] out_v,
  output reg done
);

  // States
  typedef enum logic [2:0] {
    IDLE,
    LOAD_EDGES,
    CALC_DEGREES,
    FIND_LEAVES,
    OUTPUT_EDGES,
    DONE
  } state_t;
  state_t state = IDLE;

  // Adjacency matrix (16x16)
  reg [15:0] adj_matrix [0:15];
  // Degree counters (16x4)
  reg [3:0] degree [0:15];
  // Leaves list (max 16 leaves)
  reg [3:0] leaves [0:15];
  reg [3:0] leaf_count = 0;
  // Edge output counter
  reg [3:0] edge_out_count = 0;
  // Edge loading counter
  reg [3:0] edge_load_count = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      m <= 0;
      out_u <= 0;
      out_v <= 0;
      done <= 0;
      edge_load_count <= 0;
      edge_out_count <= 0;
      leaf_count <= 0;
      for (int i = 0; i < 16; i++) begin
        adj_matrix[i] <= 0;
        degree[i] <= 0;
        leaves[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD_EDGES;
            edge_load_count <= 0;
          end
        end
        LOAD_EDGES: begin
          if (edge_index == edge_load_count) begin
            adj_matrix[u][v] <= 1;
            adj_matrix[v][u] <= 1;
            degree[u] <= degree[u] + 1;
            degree[v] <= degree[v] + 1;
            edge_load_count <= edge_load_count + 1;
            if (edge_load_count == n_minus_1_edges_count) begin
              state <= CALC_DEGREES;
            end
          end
        end
        CALC_DEGREES: begin
          state <= FIND_LEAVES;
        end
        FIND_LEAVES: begin
          leaf_count <= 0;
          for (int i = 0; i < 16; i++) begin
            if (degree[i] == 1 && i != h) begin
              leaves[leaf_count] <= i;
              leaf_count <= leaf_count + 1;
            end
          end
          // Special case: root is leaf (N=2)
          if (degree[h] == 1 && n_minus_1_edges_count == 1) begin
            leaf_count <= leaf_count + 1;
            leaves[leaf_count] <= h;
          end
          m <= (leaf_count + 1) / 2;
          state <= OUTPUT_EDGES;
          edge_out_count <= 0;
        end
        OUTPUT_EDGES: begin
          if (edge_out_count < m) begin
            if (edge_out_count * 2 + 1 < leaf_count) begin
              out_u <= leaves[edge_out_count * 2];
              out_v <= leaves[edge_out_count * 2 + 1];
            end else begin
              out_u <= leaves[edge_out_count * 2];
              out_v <= h;
            end
            edge_out_count <= edge_out_count + 1;
          end else begin
            state <= DONE;
            done <= 1;
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule