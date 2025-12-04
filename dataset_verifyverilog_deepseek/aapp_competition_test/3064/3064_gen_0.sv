module longest_path_to_1 (
  input clk,
  input rst_n,
  input start,
  input [2:0] node_count,
  input [15:0][7:0] edges,
  output reg [4:0] path_length,
  output reg done
);

localparam NODES = 8;
localparam EDGES = 16;
typedef enum logic [1:0] {IDLE, INIT, PROCESS, DONE} state_t;

// Internal registers
state_t state, next_state;
reg [7:0] adjacency_matrix [0:NODES-1];
reg [2:0] edge_min [0:EDGES-1];
reg [2:0] edge_max [0:EDGES-1];
reg [EDGES-1:0] edge_valid;

// Queue structure
reg [2:0] queue_node [0:127];
reg [4:0] queue_length [0:127];
reg [EDGES-1:0] queue_used [0:127];
reg [6:0] head_ptr, tail_ptr;
reg [127:0] queue_val;
wire queue_empty = (head_ptr == tail_ptr) && !queue_val[head_ptr];

// Processing registers
reg [2:0] proc_node;
reg [4:0] proc_length;
reg [EDGES-1:0] proc_used;
reg [4:0] max_length;
reg [6:0] cycle_count;

// Edge index calculation
function automatic [3:0] get_edge_idx(input [2:0] a, input [2:0] b);
  begin
    get_edge_idx = 4'd15;
    for (int i = 0; i < EDGES; i = i + 1) begin
      if (edge_valid[i] && ((edge_min[i] == a && edge_max[i] == b) || 
          (edge_min[i] == b && edge_max[i] == a))) begin
        get_edge_idx = i;
        break;
      end
    end
  end
endfunction

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 1'b0;
    path_length <= 5'b0;
    max_length <= 5'b0;
    head_ptr <= 7'b0;
    tail_ptr <= 7'b0;
    queue_val <= 128'b0;
    for (int i = 0; i < NODES; i = i + 1)
      adjacency_matrix[i] <= 8'b0;
    edge_valid <= 16'b0;
    cycle_count <= 7'b0;
  end
  else begin
    state <= next_state;
    case (state)
      IDLE: begin
        max_length <= 5'b0;
        done <= 1'b0;
        if (start) begin
          next_state <= INIT;
          cycle_count <= 7'b0;
        end
      end

      INIT: begin
        // Reset adjacency matrix & edge maps
        for (int i = 0; i < NODES; i = i + 1)
          adjacency_matrix[i] <= 8'b0;
        edge_valid <= 16'b0;
        
        // Parse edges input
        for (int i = 0; i < EDGES; i = i + 1) begin
          if (edges[i][0] && (edges[i][7:5] < node_count) && 
              (edges[i][4:2] < node_count) && (edges[i][7:5] != edges[i][4:2])) begin
            adjacency_matrix[edges[i][7:5]][edges[i][4:2]] <= 1'b1;
            adjacency_matrix[edges[i][4:2]][edges[i][7:5]] <= 1'b1;
            edge_min[i] <= (edges[i][7:5] < edges[i][4:2]) ? edges[i][7:5] : edges[i][4:2];
            edge_max[i] <= (edges[i][7:5] > edges[i][4:2]) ? edges[i][7:5] : edges[i][4:2];
            edge_valid[i] <= 1'b1;
          end
          else edge_valid[i] <= 1'b0;
        end
        
        // Initialize queue with all nodes
        for (int i = 0; i < node_count; i = i + 1) begin
          queue_node[tail_ptr] <= i;
          queue_length[tail_ptr] <= 5'b0;
          queue_used[tail_ptr] <= 16'b0;
          queue_val[tail_ptr] <= 1'b1;
          tail_ptr <= (tail_ptr == 7'd127) ? 7'b0 : tail_ptr + 7'b1;
        end
        
        next_state <= PROCESS;
      end

      PROCESS: begin
        cycle_count <= cycle_count + 7'b1;
        
        if (!queue_empty) begin
          // Load processing registers
          proc_node <= queue_node[head_ptr];
          proc_length <= queue_length[head_ptr];
          proc_used <= queue_used[head_ptr];
          queue_val[head_ptr] <= 1'b0;
          head_ptr <= (head_ptr == 7'd127) ? 7'b0 : head_ptr + 7'b1;
          
          // Update max_length if reached node 1
          if (proc_node == 3'b000 && proc_length > max_length)
            max_length <= proc_length;
          
          // Enqueue neighbors
          for (int i = 0; i < NODES; i = i + 1) begin
            if (adjacency_matrix[proc_node][i] && i < node_count) begin
              automatic [3:0] eidx = get_edge_idx(proc_node, i);
              if (eidx < 16 && !proc_used[eidx]) begin
                automatic [15:0] new_used = proc_used | (1 << eidx);
                
                // Only enqueue if not full
                if (queue_val[tail_ptr] == 1'b0) begin
                  queue_node[tail_ptr] <= i;
                  queue_length[tail_ptr] <= proc_length + 5'b1;
                  queue_used[tail_ptr] <= new_used;
                  queue_val[tail_ptr] <= 1'b1;
                  tail_ptr <= (tail_ptr == 7'd127) ? 7'b0 : tail_ptr + 7'b1;
                end
              end
            end
          end
        end
        
        // Check termination conditions
        if (queue_empty || cycle_count >= 7'd100) begin
          next_state <= DONE;
          path_length <= max_length;
        end
      end

      DONE: begin
        done <= 1'b1;
        if (!start) next_state <= IDLE;
      end
    endcase
  end
end

// Next state logic
always_comb begin
  case (state)
    INIT: next_state = PROCESS;
    PROCESS: next_state = (queue_empty || cycle_count >= 7'd100) ? DONE : PROCESS;
    DONE: next_state = (start) ? DONE : IDLE;
    default: next_state = IDLE;
  endcase
end

endmodule