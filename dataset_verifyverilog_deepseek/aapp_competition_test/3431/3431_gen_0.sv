module manhattan_mst(
  input clk,
  input rst_n,
  input start,
  input [3:0] num_points,
  input [9:0] x[0:7],
  input [9:0] y[0:7],
  output reg [13:0] mst_weight,
  output reg done
);

typedef struct packed {
  logic [10:0] distance;
  logic [2:0] u;
  logic [2:0] v;
} edge_t;

localparam integer MAX_EDGES = 28;
localparam integer MAX_NODES = 8;

// States
enum {IDLE, CALC_DISTANCES, SORTING, INIT_KRUSKAL, PROCESS_EDGES, DONE} state, next_state;

edge_t edges [0:MAX_EDGES-1];
edge_t sorted_edges [0:MAX_EDGES-1];
reg [2:0] parent [0:MAX_NODES-1];
reg [1:0] rank [0:MAX_NODES-1];
reg [13:0] temp_weight;
reg [4:0] edge_count;
reg [5:0] edge_index;
reg [5:0] sorted_count;
reg [9:0] sort_i, sort_j;
reg sorting_done;

// Combinational functions
function automatic [2:0] find_root(input [2:0] node);
  logic [2:0] root = node;
  while (parent[root] != root) begin
    root = parent[root];
  end
  return root;
endfunction

function automatic [10:0] abs_diff(input [9:0] a, input [9:0] b);
  return (a >= b) ? (a - b) : (b - a);
endfunction

// State machine and datapath
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 0;
    mst_weight <= 0;
  end else begin
    state <= next_state;
  end
end

always_comb begin
  next_state = state;
  case (state)
    IDLE: if (start) next_state = CALC_DISTANCES;
    CALC_DISTANCES: next_state = SORTING;
    SORTING: if (sorting_done) next_state = INIT_KRUSKAL;
    INIT_KRUSKAL: next_state = PROCESS_EDGES;
    PROCESS_EDGES: if (edge_count == (num_points-1) || edge_index == MAX_EDGES) next_state = DONE;
    DONE: next_state = IDLE;
    default: next_state = IDLE;
  endcase
end

// Edge calculation
always @(posedge clk) begin
  if (state == CALC_DISTANCES) begin
    edge_index = 0;
    for (int i = 0; i < MAX_NODES; i++) begin
      for (int j = i+1; j < MAX_NODES; j++) begin
        if (edge_index < MAX_EDGES) begin
          edges[edge_index].distance = abs_diff(x[i], x[j]) + abs_diff(y[i], y[j]);
          edges[edge_index].u = i;
          edges[edge_index].v = j;
          edge_index = edge_index + 1;
        end
      end
    end
  end
end

// Sorting (Bubble sort implementation - note: exceeds latency requirement)
always @(posedge clk) begin
  if (!rst_n) begin
    sort_i <= 0;
    sort_j <= 1;
    sorted_edges <= edges;
    sorting_done <= 0;
  end else if (state == SORTING) begin
    if (sort_i < MAX_EDGES-1) begin
      if (sort_j < MAX_EDGES - sort_i) begin
        if (sorted_edges[sort_j-1].distance > sorted_edges[sort_j].distance) begin
          edge_t temp = sorted_edges[sort_j-1];
          sorted_edges[sort_j-1] = sorted_edges[sort_j];
          sorted_edges[sort_j] = temp;
        end
        sort_j <= sort_j + 1;
      end else begin
        sort_i <= sort_i + 1;
        sort_j <= 1;
      end
    end else begin
      sorting_done <= 1;
    end
  end
end

// Union-Find and MST calculation
always @(posedge clk) begin
  if (!rst_n) begin
    mst_weight <= 0;
    done <= 0;
    edge_index <= 0;
    edge_count <= 0;
  end else case(state)
    INIT_KRUSKAL: begin
      for (int i = 0; i < MAX_NODES; i++) begin
        parent[i] = i;
        rank[i] = 0;
      end
      temp_weight <= 0;
      edge_count <= 0;
      edge_index <= 0;
    end
    PROCESS_EDGES: begin
      if (edge_index < MAX_EDGES) begin
        logic [2:0] u = sorted_edges[edge_index].u;
        logic [2:0] v = sorted_edges[edge_index].v;
        logic [2:0] u_root = find_root(u);
        logic [2:0] v_root = find_root(v);
        if (u_root != v_root) begin
          // Union
          if (rank[u_root] > rank[v_root]) parent[v_root] = u_root;
          else if (rank[u_root] < rank[v_root]) parent[u_root] = v_root;
          else begin
            parent[v_root] = u_root;
            rank[u_root] = rank[u_root] + 1;
          end
          temp_weight <= temp_weight + sorted_edges[edge_index].distance;
          edge_count <= edge_count + 1;
        end
        edge_index <= edge_index + 1;
      end
    end
    DONE: begin
      mst_weight <= temp_weight;
      done <= 1;
    end
    default: begin
      done <= 0;
    end
  endcase
end

endmodule