module tunnel_connector(
  input clk,
  input rst_n,
  input start,
  input [2:0] n_islands,
  input [3:0] n_trees,
  input [15:0] k,
  input [23:0] island_x[0:7],
  input [23:0] island_y[0:7],
  input [23:0] island_r[0:7],
  input [23:0] tree_x[0:15],
  input [23:0] tree_y[0:15],
  input [15:0] tree_h[0:15],
  output reg done,
  output reg impossible,
  output reg [31:0] tunnel_length
);
  
  typedef enum {
    IDLE, ASSIGN_TREES, CALC_THROWS, BUILD_GRAPH,
    CHECK_CONNECTED, FIND_TUNNEL, DONE
  } state_t;
  state_t state, next_state;
  
  reg [2:0] tree_island [0:15];
  reg [31:0] throw_dist [0:15];
  
  reg [2:0] parent [0:7];
  reg [2:0] rank [0:7];
  
  reg [3:0] tree_ctr;
  reg [2:0] island_ctr;
  reg [4:0] pair_ctr;
  reg [3:0] throw_ctr;
  
  reg [2:0] i, j;
  reg [47:0] sq_dist;
  reg [23:0] sqrt_res;
  reg [5:0] sqrt_ctr;
  reg [31:0] min_len;
  reg has_path;
  
  reg signed [23:0] dx, dy;
  reg [47:0] dx_sq, dy_sq;
  reg [47:0] dist_sq;
  reg [31:0] sum_throw;
  reg [47:0] sum_throw_sq;
  reg found;
  
  function [2:0] find(input [2:0] x);
    if (parent[x] != x)
      parent[x] = find(parent[x]);
    find = parent[x];
  endfunction
  
  function void union_uf(input [2:0] x, input [2:0] y);
    reg [2:0] root_x, root_y;
    begin
      root_x = find(x);
      root_y = find(y);
      if (root_x == root_y) return;
      if (rank[root_x] < rank[root_y])
        parent[root_x] = root_y;
      else if (rank[root_x] > rank[root_y])
        parent[root_y] = root_x;
      else begin
        parent[root_y] = root_x;
        rank[root_x]++;
      end
    end
  endfunction
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      impossible <= 0;
      tunnel_length <= 0;
    end
    else begin
      case (state)
        IDLE: begin
          done <= 0;
          impossible <= 0;
          tunnel_length <= 0;
          if (start) begin
            state <= ASSIGN_TREES;
            tree_ctr <= 0;
            island_ctr <= 0;
          end
        end
        
        ASSIGN_TREES: begin
          if (tree_ctr < n_trees) begin
            dx = tree_x[tree_ctr] - island_x[island_ctr];
            dy = tree_y[tree_ctr] - island_y[island_ctr];
            dist_sq = dx*dx + dy*dy;
            if (dist_sq <= island_r[island_ctr]*island_r[island_ctr]) begin
              tree_island[tree_ctr] <= island_ctr;
              tree_ctr <= tree_ctr + 1;
              island_ctr <= 0;
            end
            else if (island_ctr < n_islands-1)
              island_ctr <= island_ctr + 1;
            else begin
              tree_island[tree_ctr] <= 0; // Safe assign if none
              tree_ctr <= tree_ctr + 1;
              island_ctr <= 0;
            end
          end
          else begin
            state <= CALC_THROWS;
            throw_ctr <= 0;
          end
        end
        
        CALC_THROWS: begin
          if (throw_ctr < n_trees) begin
            throw_dist[throw_ctr] <= k * tree_h[throw_ctr];
            throw_ctr <= throw_ctr + 1;
          end
          else begin
            state <= BUILD_GRAPH;
            for (int v=0; v<8; v++) begin
              parent[v] <= v;
              rank[v] <= v;
            end
          end
        end
  end
endmodule