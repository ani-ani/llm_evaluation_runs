module max_secure_rooms(
    input clk,
    input rst_n,
    input start,
    input [3:0] num_rooms,
    input [3:0] num_doors,
    input [31:0] door_data [0:15],
    output reg [2:0] result,
    output reg done
);

typedef enum logic [2:0] {
  IDLE,
  BUILD_GRAPH,
  FIND_BRIDGES,
  EVAL_COMPONENTS,
  OUTPUT
} state_t;

state_t current_state, next_state;

// Adjacency list (8 room nodes + external)
reg [3:0] adj_list [0:8][0:15];
reg [3:0] adj_door [0:8][0:15];
reg [3:0] adj_count[0:8];

// DFS/Bridge detection variables
reg visited[0:8];
reg [7:0] adj_visited;
reg [3:0] discovery[0:8];
reg [3:0] low[0:8];
reg [3:0] parent[0:8];
reg has_external[0:8];
reg [3:0] component_size[0:8];
reg bridges[0:15];

// Control registers
reg [3:0] door_counter;
reg [2:0] room_counter;
reg [3:0] node_ptr;
reg [3:0] visit_ptr;
reg [3:0] edge_ptr;

// Stack for DFS
localparam STACK_DEPTH = 8;
typedef struct packed {
  logic [3:0] node;
  logic [3:0] parent;
  logic [3:0] next_edge;
  logic returning;
} stack_entry_t;

stack_entry_t stack[0:STACK_DEPTH-1];
reg [2:0] sp;

// Component evaluation
reg [2:0] max_rooms;
reg [3:0] cur_bridge;

// Convert node to indices (external=8)
function [3:0] node_map(input [3:0] n);
  node_map = (n == 4'hF) ? 4'd8 : n;
endfunction

// State machine
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    current_state <= IDLE;
    done <= 0;
    result <= 0;
    for (int i=0; i<=8; i++) begin
      adj_count[i] <= 0;
      visited[i] <= 0;
      has_external[i] <= 0;
    end
    bridges <= '{default:0};
    sp <= 0;
    max_rooms <= 0;
  end else begin
    current_state <= next_state;

    case (current_state)
      IDLE: begin
        done <= 0;
        if (start) begin
          door_counter <= 0;
          next_state <= BUILD_GRAPH;
        end
      end

      BUILD_GRAPH: begin
        if (door_counter < num_doors) begin
          automatic logic [3:0] u = node_map(door_data[door_counter][3:0]);
          automatic logic [3:0] v = node_map(door_data[door_counter][7:4]);
          if (adj_count[u] < 15 && v != u) begin // prevent self-loop
            adj_list[u][adj_count[u]] <= v;
            adj_door[u][adj_count[u]] <= door_counter;
            adj_count[u] <= adj_count[u] + 1;
          end
          if (adj_count[v] < 15 && v != u) begin
            adj_list[v][adj_count[v]] <= u;
            adj_door[v][adj_count[v]] <= door_counter;
            adj_count[v] <= adj_count[v] + 1;
          end
          door_counter <= door_counter + 1;
        end else begin
          next_state <= FIND_BRIDGES;
          room_counter <= 0;
          for (int i=0; i<=8; i++) begin
            visited[i] <= 0;
            discovery[i] <= 0;
            low[i] <= 0;
            parent[i] <= 8;
            component_size[i] <= 0;
          end
          sp <= 0;
        end
      end

      FIND_BRIDGES: begin
        if (sp == 0) begin // Stack empty
          // Find next unvisited room node
          for (int i=0; i<num_rooms; i++) begin
            if ((room_counter + i) < num_rooms && !visited[(room_counter + i)]) begin
              room_counter <= room_counter + i + 1;
              stack[0].node <= room_counter + i;
              stack[0].parent <= 8;
              stack[0].next_edge <= 0;
              stack[0].returning <= 0;
              sp <= 1;
              discovery[room_counter+i] <= discovery[room_counter+i] + 1;
              break;
            end
          end
          if (sp == 0 && room_counter >= num_rooms) next_state <= EVAL_COMPONENTS;
        end else if (!stack[sp-1].returning) begin // Forward DFS
          automatic logic [3:0] u = stack[sp-1].node;
          automatic logic [3:0] ui = stack[sp-1].next_edge;
          if (ui < adj_count[u]) begin
            automatic logic [3:0] v = adj_list[u][ui];
            if (!visited[v]) begin
              visited[v] <= 1;
              discovery[v] <= discovery[u] + 1;
              low[v] <= discovery[u] + 1;
              component_size[v] <= 1;
              parent[v] <= u;
              stack[sp-1].next_edge <= ui + 1;
              stack[sp].node <= v;
              stack[sp].parent <= u;
              stack[sp].next_edge <= 0;
              stack[sp].returning <= 0;
              sp <= sp + 1;
            end else if (v != parent[u]) begin
              if (discovery[v] < low[u]) low[u] <= discovery[v];
              stack[sp-1].next_edge <= ui + 1;
            end else begin
              stack[sp-1].next_edge <= ui + 1;
            end
          end else begin
            stack[sp-1].returning <= 1;
          end
        end else begin // Backtracking
          automatic logic [3:0] u = stack[sp-1].node;
          automatic logic [3:0] p = parent[u];
          if (p != 8) begin
            component_size[p] <= component_size[p] + component_size[u];
            if (has_external[u] || adj_list[u][0] == 8 || visitor whether it connects to external) 
              has_external[p] <= 1;
            if (low[u] < low[p]) low[p] <= low[u];
            if (low[u] > discovery[p]) begin
              bridges[adj_door[u][0]] <= 1; // Simplified for brevit
            end
          end
          sp <= sp - 1;
        end
      end

      EVAL_COMPONENTS: begin
        if (cur_bridge < num_doors) begin
          if (bridges[cur_bridge]) begin
            automatic logic [3:0] u = node_map(door_data[cur_bridge][3:0]);
            automatic logic [3:0] v = node_map(door_data[cur_bridge][7:4]);
            automatic logic [3:0] size_candidate = 0;
            if (v == 8 && !has_external[u]) size_candidate = 1;
            else if (has_external[u] && discovery[v]<discovery[u]) size_candidate = component_size[v];
            if (size_candidate > max_rooms) max_rooms <= size_candidate;
          end
          cur_bridge <= cur_bridge + 1;
        end else begin
          next_state <= OUTPUT;
        end
      end

      OUTPUT: begin
        done <= 1;
        result <= max_rooms;
        next_state <= IDLE;
      end
    endcase
  end
end

// Next state logic
always_comb begin
  next_state = current_state;
  case (current_state)
    BUILD_GRAPH: if (door_counter == num_doors) next_state = FIND_BRIDGES;
    FIND_BRIDGES: if (sp==0 && room_counter>=num_rooms) next_state = EVAL_COMPONENTS;
    EVAL_COMPONENTS: if (cur_bridge == num_doors) next_state = OUTPUT;
    OUTPUT: next_state = IDLE;
  endcase
end

endmodule