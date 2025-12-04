module tree_optimizer(
  input clk,
  input rst_n,
  input start,
  input [2:0] num_nodes,
  input [55:0] edges,
  output reg [2:0] min_flights,
  output reg [3:0] cancel_a, cancel_b,
  output reg [3:0] add_a, add_b,
  output reg done
);

  // Internal signals and registers
  reg [7:0] adj [7:0];
  reg [2:0] state;
  reg [2:0] edge_index;
  reg [2:0] best_min_max;
  reg [3:0] best_cancel_a, best_cancel_b;
  reg [3:0] best_add_a, best_add_b;
  
  // BFS related
  reg [2:0] current_node;
  reg [7:0] visited;
  reg [2:0] queue [0:7];
  reg [3:0] front_ptr, back_ptr;
  reg [3:0] distances [0:7];
  reg [3:0] max_distance;
  reg [2:0] farthest_node;
  reg [3:0] subtree_nodes;
  
  // Eccentricities and A.Diameters
  reg [3:0] dist_u[0:7], dist_v[0:7];
  reg [3:0] ecc[0:7];
  reg [3:0] min_ecc;
  reg [3:0] temp_min_ecc;
  reg [3:0] diam;
  
  // Temporary storage for edge removal
  reg [2:0] edge_a, edge_b;
  reg save_ab, save_ba;
  
  // Subtrees
  reg [7:0] subtree1;
  reg [7:0] subtree2;
  
  // State definitions
  localparam IDLE            = 3'b000;
  localparam INIT_ADJ        = 3'b001;
  localparam SELECT_EDGE     = 3'b010;
  localparam REMOVE_EDGE     = 3'b011;
  localparam BFS_SUBTREE1    = 3'b100;
  localparam BFS_U1          = 3'b101;
  localparam BFS_V1          = 3'b110;
  localparam COMPUTE_ECC1    = 3'b111;
  localparam BFS_U2          = 3'b000;
  localparam BFS_V2          = 3'b001;
  localparam COMPUTE_ECC2    = 3'b010;
  localparam EVAL_CANDIDATE  = 3'b011;
  localparam RESTORE_EDGE    = 3'b100;
  localparam FINISH          = 3'b101;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      min_flights <= 0;
      cancel_a <= 0;
      cancel_b <= 0;
      add_a <= 0;
      add_b <= 0;
      best_min_max <= 7;
      edge_index <= 0;
      for (int i=0; i<8; i++) adj[i] <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= INIT_ADJ;
            edge_index <= 0;
            best_min_max <= 7;
          end
        end
        
        INIT_ADJ: begin
          for (int i=0; i<8; i++) adj[i] <= 0;
          for (int i=0; i<8; i++) begin
            if (edges[i*7 + 6]) begin // valid bit
              edge_a = edges[i*7 +: 3];
              edge_b = edges[i*7 +3 +: 3];
              adj[edge_a][edge_b] <= 1;
              adj[edge_b][edge_a] <= 1;
            end
          end
          state <= SELECT_EDGE;
        end
        
        SELECT_EDGE: begin
          if (edge_index < num_nodes-1) begin // num_nodes-1 edges
            // Find next valid edge (simplify for now - assume edges ordered)
            state <= REMOVE_EDGE;
            edge_a = edges[edge_index*7 +: 3];
            edge_b = edges[edge_index*7 +3 +: 3];
          end else begin
            state <= FINISH;
          end
        end
        
        REMOVE_EDGE: begin
          save_ab <= adj[edge_a][edge_b];
          save_ba <= adj[edge_b][edge_a];
          adj[edge_a][edge_b] <= 0;
          adj[edge_b][edge_a] <= 0;
          // Initialize BFS for subtree1
          front_ptr <= 0;
          back_ptr <= 0;
          visited <= 0;
          for (int i=0; i<8; i++) distances[i] <= 0;
          current_node <= edge_a;
          visited[edge_a] <= 1;
          queue[back_ptr] <= edge_a;
          back_ptr <= back_ptr + 1;
          state <= BFS_SUBTREE1;
        end
        
        BFS_SUBTREE1: begin
          if (front_ptr < back_ptr) begin
            current_node <= queue[front_ptr];
            front_ptr <= front_ptr + 1;
            state <= BFS_SUBTREE1;
          end else begin
            // Get subtree1 nodes from visited
            subtree1 <= visited;
            // Init BFS to find u (max distance from edge_a)
            front_ptr <= 0;
            back_ptr <= 0;
            for (int i=0; i<8; i++) distances[i] <= 0;
            visited <= 0;
            visited[edge_a] <= 1;
            queue[back_ptr] <= edge_a;
            back_ptr <= back_ptr + 1;
            state <= BFS_U1;
          end
        end
        
        BFS_U1: begin
          if (front_ptr < back_ptr) begin
            current_node <= queue[front_ptr];
            front_ptr <= front_ptr + 1;
            state <= BFS_U1;
          end else begin
            // Find node with max distance - u
            max_distance = 0;
            for (int i=0; i<8; i++) begin
              if (distances[i] > max_distance && subtree1[i]) begin
                max_distance = distances[i];
                farthest_node = i;
              end
            end
            // Run BFS from u to get dist_u and find v
            front_ptr <= 0;
            back_ptr <= 0;
            for (int i=0; i<8; i++) distances[i] <= 0;
            visited <= 0;
            visited[farthest_node] <= 1;
            queue[back_ptr] <= farthest_node;
            back_ptr <= back_ptr + 1;
            diam <= 0;
            state <= BFS_V1;
          end
        end
        
        BFS_V1: begin
          if (front_ptr < back_ptr) begin
            current_node <= queue[front_ptr];
            front_ptr <= front_ptr + 1;
            state <= BFS_V1;
          end else begin
            // Find v and record dist_u
            max_distance = 0;
            for (int i=0; i<8; i++) begin
              dist_u[i] <= distances[i];
              if (distances[i] > max_distance && subtree1[i]) begin
                max_distance = distances[i];
                farthest_node = i;
              end
            end
            diam <= max_distance;
            // Run BFS from v to get dist_v
            front_ptr <= 0;
            back_ptr <= 0;
            for (int i=0; i<8; i++) distances[i] <= 0;
            visited <= 0;
            visited[farthest_node] <= 1;
            queue[back_ptr] <= farthest_node;
            back_ptr <= back_ptr + 1;
            state <= COMPUTE_ECC1;
          end
        end
        
        COMPUTE_ECC1: begin
          if (front_ptr < back_ptr) begin
            current_node <= queue[front_ptr];
            front_ptr <= front_ptr + 1;
            state <= COMPUTE_ECC1;
          end else begin
            for (int i=0; i<8; i++) begin
              dist_v[i] <= distances[i];
              ecc[i] <= (dist_u[i] > dist_v[i]) ? dist_u[i] : dist_v[i];
            end
            // Find min_ecc for this subtree
            min_ecc = 15;
            for (int i=0; i<8; i++) begin
              if (subtree1[i] && ecc[i] < min_ecc)
                min_ecc = ecc[i];
            end
            temp_min_ecc <= min_ecc;
            // Repeat for subtree2
            state <= BFS_U2;
          end
        end
        
        // Similar states for subtree2 (BFS_U2, BFS_V2, COMPUTE_ECC2)...
        // For brevity, only key states are outlined here
        
        EVAL_CANDIDATE: begin
          // Compute candidate max = max(diam1, diam2, min_ecc1 + min_ecc2 + 1)
          // Compare with best_min_max
          // Update best solution if needed
          
          edge_index <= edge_index + 1;
          state <= RESTORE_EDGE;
        end
        
        RESTORE_EDGE: begin
          adj[edge_a][edge_b] <= save_ab;
          adj[edge_b][edge_a] <= save_ba;
          state <= SELECT_EDGE;
        end
        
        FINISH: begin
          done <= 1;
          cancel_a <= best_cancel_a + 1; // Convert to 1-8
          cancel_b <= best_cancel_b + 1;
          add_a <= best_add_a + 1;
          add_b <= best_add_b + 1;
          min_flights <= best_min_max;
          state <= IDLE;
        end
      endcase
    end
  end

  // BFS processing combinatorial logic
  always @(*) begin
    if (state == BFS_SUBTREE1 && front_ptr < back_ptr) begin
      // Process current_node neighbors
      for (int i=0; i<8; i++) begin
        if (adj[current_node][i] && !visited[i]) begin
          visited[i] = 1;
          distances[i] = distances[current_node] + 1;
          queue[back_ptr] = i;
          back_ptr = back_ptr + 1;
        end
      end
    end
    // Similar for other BFS states...
  end
endmodule