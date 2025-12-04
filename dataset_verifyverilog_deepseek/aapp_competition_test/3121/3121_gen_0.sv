package cave_pathfinder_pkg;
  typedef enum logic [3:0] {
    IDLE        = 4'b0000,
    BUILD_ADJ   = 4'b0001,
    DFS_INIT    = 4'b0010,
    POP_STACK   = 4'b0011,
    CHECK_NODE  = 4'b0100,
    PROCESS_EDGE = 4'b0101,
    UPDATE_MAX  = 4'b0110,
    SEARCH_DONE = 4'b0111
  } state_t;
endpackage

module cave_pathfinder(
  input clk,
  input rst_n,
  input start,
  input [15:0] unnars_attack,
  input [15:0] unnars_health,
  input [3:0] num_nodes,
  input [3:0] num_passages,
  input [63:0] passages [0:15],
  output reg [15:0] max_health,
  output reg done,
  output reg oh_no
);
  import cave_pathfinder_pkg::*;
  
  // Adjacency list data structures
  typedef struct packed {
    logic [3:0] to;
    logic [15:0] a;
    logic [15:0] h;
  } edge_t;
  
  localparam MAX_NODES = 8;
  localparam MAX_EDGES_PER_NODE = 4;
  
  edge_t adj_list [0:MAX_NODES-1][0:MAX_EDGES_PER_NODE-1];
  logic [1:0] edge_count [0:MAX_NODES-1];
  
  // Stack data structure
  typedef struct packed {
    logic [3:0] node;
    logic [15:0] health;
    logic [7:0] visited;
  } stack_entry_t;
  
  localparam STACK_DEPTH = 16;
  stack_entry_t stack [0:STACK_DEPTH-1];
  logic [4:0] stack_ptr;
  
  // Control signals
  state_t current_state, next_state;
  logic [15:0] max_health_reg;
  logic [3:0] passage_counter;
  logic [3:0] target_node;
  
  // Current processing registers
  stack_entry_t current_entry;
  logic [2:0] edge_index;
  
  // Fight calculation function
  function automatic logic [16:0] fight_calc(
    input [15:0] current_health,
    input [15:0] A,
    input [15:0] enemy_a,
    input [15:0] enemy_h
  );
    logic [31:0] rounds_needed;
    logic [31:0] damage;
    logic [15:0] new_health;
    logic valid;
    
    if (A == 16'b0) rounds_needed = 32'hFFFF;
    else rounds_needed = (enemy_h + A - 1) / A;
    
    if (rounds_needed == 0) damage = 0;
    else damage = (rounds_needed - 1) * enemy_a;
    
    new_health = (damage >= current_health) ? 16'b0 : (current_health - damage[15:0]);
    valid = (new_health >= 16'd1) && (rounds_needed < 32'hFFFF);
    return {valid, new_health};
  endfunction
  
  // FSM and control logic
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      current_state <= IDLE;
      max_health_reg <= 16'b0;
      max_health <= 16'b0;
      done <= 1'b0;
      oh_no <= 1'b0;
      stack_ptr <= 0;
      target_node <= 4'b0;
      for (int i=0; i<MAX_NODES; i++) edge_count[i] <= 0;
    end
    else begin
      done <= 1'b0;  // Pulse done for one cycle
      
      case (current_state)
        IDLE: begin
          max_health_reg <= 16'b0;
          oh_no <= 1'b0;
          if (start) begin
            current_state <= BUILD_ADJ;
            passage_counter <= 0;
            for (int i=0; i<MAX_NODES; i++) edge_count[i] <= 0;
            target_node <= num_nodes - 1;
          end
        end
        
        BUILD_ADJ: begin
          if (passage_counter < num_passages) begin
            logic [3:0] from_node = passages[passage_counter][3:0];
            if ((from_node < num_nodes) && (edge_count[from_node] < MAX_EDGES_PER_NODE)) begin
              adj_list[from_node][edge_count[from_node]] <= '{
                to: passages[passage_counter][7:4],
                a: passages[passage_counter][23:8],
                h: passages[passage_counter][39:24]
              };
              edge_count[from_node] <= edge_count[from_node] + 1'b1;
            end
            passage_counter <= passage_counter + 1'b1;
          end
          else begin
            current_state <= DFS_INIT;
          end
        end
        
        DFS_INIT: begin
          if (stack_ptr < STACK_DEPTH) begin
            stack[stack_ptr] <= '{
              node: 0,
              health: unnars_health,
              visited: 8'b00000001
            };
            stack_ptr <= stack_ptr + 1'b1;
            current_state <= POP_STACK;
          end
        end
        
        POP_STACK: begin
          if (stack_ptr > 0) begin
            current_entry <= stack[stack_ptr-1];
            stack_ptr <= stack_ptr - 1'b1;
          end
          current_state <= CHECK_NODE;
        end
        
        CHECK_NODE: begin
          if (current_entry.node == target_node) begin
            if (current_entry.health > max_health_reg) begin
              max_health_reg <= current_entry.health;
            end
            current_state <= (stack_ptr == 0) ? SEARCH_DONE : POP_STACK;
          end
          else begin
            edge_index <= 0;
            current_state <= PROCESS_EDGE;
          end
        end
        
        PROCESS_EDGE: begin
          if (edge_index < edge_count[current_entry.node]) begin
            edge_t current_edge = adj_list[current_entry.node][edge_index];
            if (~current_entry.visited[current_edge.to]) begin
              logic [16:0] fight_result = fight_calc(
                current_entry.health,
                unnars_attack,
                current_edge.a,
                current_edge.h
              );
              
              if (fight_result[16] && (stack_ptr < STACK_DEPTH)) begin
                stack[stack_ptr] <= '{
                  node: current_edge.to,
                  health: fight_result[15:0],
                  visited: current_entry.visited | (8'b1 << current_edge.to)
                };
                stack_ptr <= stack_ptr + 1'b1;
              end
            end
            edge_index <= edge_index + 1'b1;
          end
          else begin
            current_state <= (stack_ptr == 0) ? SEARCH_DONE : POP_STACK;
          end
        end
        
        SEARCH_DONE: begin
          max_health <= max_health_reg;
          done <= 1'b1;
          oh_no <= (max_health_reg == 16'b0);
          current_state <= IDLE;
        end
        
        default: current_state <= IDLE;
      endcase
    end
  end
endmodule