module vertex_controller(
  input clk,                         // System clock
  input rst_n,                       // Active-low reset
  input start,                       // Start computation
  input reg [31:0] vertex_vals [0:7],    // Vertex a_i values (Q16.16 fixed-point)
  input reg [31:0] edge_weights [0:6],   // Edge weights (parent connections)
  output reg [3:0] control_counts [0:7], // Control counts for each vertex
  output reg done                    // High when computation complete
);

  // State machine states
  localparam IDLE = 0;
  localparam PRECOMP = 1;
  localparam COMPARE = 2;
  localparam DONE = 3;

  reg [1:0] state;
  
  // DFS traversal registers
  reg [2:0] v_index;
  reg [3:0] count [0:7];
  reg [2:0] stack_ptr;
  reg [2:0] stack_node [0:7];
  reg [31:0] stack_dist [0:7];
  reg pushing_mode;
  reg [2:0] current_node;
  reg [31:0] current_dist;
  reg [2:0] child_idx;
  
  // Precomputation registers
  reg [3:0] child_count [0:7];
  reg [2:0] child_list [0:7][0:7];
  reg [2:0] node, parent, child;
  reg [31:0] dist, new_dist;
  integer i, j;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      v_index <= 0;
      for (i = 0; i < 8; i++) count[i] <= 0;
      stack_ptr <= 0;
      for (i = 0; i < 8; i++) begin
        stack_node[i] <= 0;
        stack_dist[i] <= 0;
      end
      pushing_mode <= 0;
      current_node <= 0;
      current_dist <= 0;
      child_idx <= 0;
      for (i = 0; i < 8; i++) child_count[i] <= 0;
      for (i = 0; i < 8; i++) 
        for (j = 0; j < 8; j++) 
          child_list[i][j] <= 0;
    end
    else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PRECOMP;
          end
        end
        
        PRECOMP: begin
          // Initialize child counts
          for (i = 0; i < 8; i++) child_count[i] = 0;
          
          // Build children lists from parent array
          for (j = 0; j < 7; j++) begin
            parent = edge_weights[j][2:0];
            if (parent < 8) begin
              child = j + 1;
              child_list[parent][child_count[parent]] = child;
              child_count[parent] = child_count[parent] + 1;
            end
          end
          
          // Initialize for first vertex
          v_index = 0;
          stack_ptr = 1;
          stack_node[0] = v_index;
          stack_dist[0] = 0;
          count[v_index] = 0;
          pushing_mode = 0;
          state <= COMPARE;
        end
        
        COMPARE: begin
          if (pushing_mode) begin
            // Pushing children of current node
            if (child_idx < child_count[current_node]) begin
              child = child_list[current_node][child_idx];
              new_dist = current_dist + edge_weights[child-1];
              stack_node[stack_ptr] = child;
              stack_dist[stack_ptr] = new_dist;
              stack_ptr = stack_ptr + 1;
              child_idx = child_idx + 1;
              
              if (child_idx == child_count[current_node]) begin
                pushing_mode = 0;
              end
            end
          end
          else begin
            if (stack_ptr > 0) begin
              // Pop node and check condition
              node = stack_node[stack_ptr-1];
              dist = stack_dist[stack_ptr-1];
              stack_ptr = stack_ptr - 1;
              
              if (dist <= vertex_vals[node]) begin
                count[v_index] = count[v_index] + 1;
              end
              
              // Start pushing children if any
              if (child_count[node] > 0) begin
                current_node = node;
                current_dist = dist;
                child_idx = 0;
                pushing_mode = 1;
              end
            end
            else begin
              // Finished current vertex, move to next
              v_index = v_index + 1;
              if (v_index < 8) begin
                stack_ptr = 1;
                stack_node[0] = v_index;
                stack_dist[0] = 0;
                count[v_index] = 0;
              end
              else begin
                state <= DONE;
                done <= 1;
              end
            end
          end
        end
        
        DONE: begin
          // Stay in DONE state
        end
      endcase
    end
  end

  // Assign outputs
  for (i = 0; i < 8; i++) begin
    control_counts[i] = count[i];
  end

endmodule