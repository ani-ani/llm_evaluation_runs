module constrained_mst(
  input clk,
  input rst_n,
  input start,
  input [2:0] num_nodes,
  input [3:0] num_edges,
  input [2:0] num_special,
  input [2:0] required_mix_edges,
  input [2:0] special1,
  input [2:0] special2,
  input [2:0] special3,
  input [2:0] edge1_a, input [2:0] edge1_b, input [6:0] edge1_cost,
  input [2:0] edge2_a, input [2:0] edge2_b, input [6:0] edge2_cost,
  input [2:0] edge3_a, input [2:0] edge3_b, input [6:0] edge3_cost,
  input [2:0] edge4_a, input [2:0] edge4_b, input [6:0] edge4_cost,
  input [2:0] edge5_a, input [2:0] edge5_b, input [6:0] edge5_cost,
  input [2:0] edge6_a, input [2:0] edge6_b, input [6:0] edge6_cost,
  input [2:0] edge7_a, input [2:0] edge7_b, input [6:0] edge7_cost,
  input [2:0] edge8_a, input [2:0] edge8_b, input [6:0] edge8_cost,
  output reg [10:0] total_cost,
  output reg done,
  output reg error
);

  typedef struct packed {
    logic [2:0] a;
    logic [2:0] b;
    logic [6:0] cost;
  } edge_t;

  edge_t [7:0] edges;
  edge_t [7:0] sorted_edges;
  edge_t [7:0] next_sorted;

  reg [2:0] parent [0:7];
  reg [2:0] rank [0:7];

  typedef enum logic [2:0] { IDLE, SORT, INIT, MAIN, FINISH } state_t;
  state_t state;

  reg [3:0] sort_i;
  reg [3:0] sort_j;
  reg [2:0] main_index;

  reg [10:0] cost_acc;
  reg [3:0] mst_edges;
  reg [2:0] mix_edges;
  reg [7:0] cycles;

  function logic [2:0] find(logic [2:0] j);
    logic [2:0] root;
    root = j;
    root = (parent[root] != root) ? parent[root] : root;
    root = (parent[root] != root) ? parent[root] : root;
    root = (parent[root] != root) ? parent[root] : root;
    root = (parent[root] != root) ? parent[root] : root;
    return root;
  endfunction

  function logic is_special(logic [2:0] node);
    return (node == special1 || node == special2 || node == special3);
  endfunction

  function logic is_mix(logic [2:0] a, logic [2:0] b);
    logic a_s = is_special(a);
    logic b_s = is_special(b);
    return (a_s & ~b_s) | (~a_s & b_s);
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      error <= 0;
      total_cost <= 0;
      cost_acc <= 0;
      mst_edges <= 0;
      mix_edges <= 0;
      for (int i=0; i<8; i=i+1) begin
        parent[i] <= i;
        rank[i] <= 0;
      end
      cycles <= 0;
    end else begin
      case(state)
        IDLE: begin
          done <= 0;
          error <= 0;
          cycles <= 0;
          if (start) begin
            edges[0].a <= edge1_a; edges[0].b <= edge1_b; edges[0].cost <= edge1_cost;
            edges[1].a <= edge2_a; edges[1].b <= edge2_b; edges[1].cost <= edge2_cost;
            edges[2].a <= edge3_a; edges[2].b <= edge3_b; edges[2].cost <= edge3_cost;
            edges[3].a <= edge4_a; edges[3].b <= edge4_b; edges[3].cost <= edge4_cost;
            edges[4].a <= edge5_a; edges[4].b <= edge5_b; edges[4].cost <= edge5_cost;
            edges[5].a <= edge6_a; edges[5].b <= edge6_b; edges[5].cost <= edge6_cost;
            edges[6].a <= edge7_a; edges[6].b <= edge7_b; edges[6].cost <= edge7_cost;
            edges[7].a <= edge8_a; edges[7].b <= edge8_b; edges[7].cost <= edge8_cost;
            sorted_edges <= edges;
            cost_acc <= 0;
            mst_edges <= 0;
            mix_edges <= 0;
            state <= SORT;
            sort_i <= 0;
            sort_j <= 0;
          end
        end

        SORT: begin
          if (sort_i < 7) begin
            if (sort_j < 7 - sort_i) begin
              if (sorted_edges[sort_j].cost > sorted_edges[sort_j+1].cost) begin
                edge_t temp = sorted_edges[sort_j];
                sorted_edges[sort_j] <= sorted_edges[sort_j+1];
                sorted_edges[sort_j+1] <= temp;
              end
              sort_j <= sort_j + 1;
            end else begin
              sort_i <= sort_i + 1;
              sort_j <= 0;
            end
          end else begin
            state <= INIT;
          end
        end

        INIT: begin
          for (int i=0; i<8; i=i+1) begin
            parent[i] <= i;
            rank[i] <= 0;
          end
          cost_acc <= 0;
          mst_edges <= 0;
          mix_edges <= 0;
          main_index <= 0;
          state <= MAIN;
        end

        MAIN: begin
          cycles <= cycles + 1;
          if (main_index < num_edges && mst_edges < (num_nodes - 1)) begin
            edge_t current = sorted_edges[main_index];
            logic [2:0] root_a = find(current.a);
            logic [2:0] root_b = find(current.b);
            if (root_a != root_b) begin
              if (is_mix(current.a, current.b)) mix_edges <= mix_edges + 1;
              cost_acc <= cost_acc + current.cost;
              mst_edges <= mst_edges + 1;
              if (rank[root_a] > rank[root_b]) begin
                parent[root_b] <= root_a;
              end else begin
                parent[root_a] <= root_b;
                if (rank[root_a] == rank[root_b]) rank[root_b] <= rank[root_b] + 1;
              end
            end
            main_index <= main_index + 1;
          end else begin
            state <= FINISH;
          end
        end

        FINISH: begin
          if (mst_edges == (num_nodes - 1) && mix_edges == required_mix_edges) begin
            total_cost <= cost_acc;
            error <= 0;
          end else begin
            error <= 1;
          end
          done <= 1;
          state <= IDLE;
        end
      endcase

      if (cycles == 127) begin
        state <= FINISH;
        error <= 1;
        done <= 1;
      end
    end
  end
endmodule