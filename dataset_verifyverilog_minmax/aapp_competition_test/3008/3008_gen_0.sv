module assistant_ranker(
  input clk,
  input rst_n,
  input start,
  input [15:0] K,
  input [15:0] a_array [0:7],
  input [15:0] b_array [0:7],
  output reg [3:0] max_ranks,
  output reg done
);

  // State machine states
  typedef enum logic [2:0] {
    IDLE = 3'b000,
    COMPARE = 3'b001,
    BUILD_GRAPH = 3'b010,
    COMPUTE_RANKS = 3'b011,
    DONE = 3'b100
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [2:0] compare_counter;
  reg [7:0] dominance_matrix [0:7][0:7];
  reg [15:0] a_reg [0:7];
  reg [15:0] b_reg [0:7];
  reg [15:0] K_reg;

  // Bipartite matching variables for Dilworth's algorithm
  reg [7:0] matchL [0:7]; // matching from left to right
  reg [7:0] matchR [0:7]; // matching from right to left
  reg visited [0:7];
  reg [7:0] path [0:7];
  reg [2:0] path_length;
  
  reg [3:0] max_chain_cover;
  reg compute_done;
  reg [2:0] match_iteration;

  // State machine sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end

  // State machine combinational logic
  always @(*) begin
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = COMPARE;
        end else begin
          next_state = IDLE;
        end
      end
      
      COMPARE: begin
        if (compare_counter == 7) begin
          next_state = BUILD_GRAPH;
        end else begin
          next_state = COMPARE;
        end
      end
      
      BUILD_GRAPH: begin
        next_state = COMPUTE_RANKS;
      end
      
      COMPUTE_RANKS: begin
        if (compute_done) begin
          next_state = DONE;
        end else begin
          next_state = COMPUTE_RANKS;
        end
      end
      
      DONE: begin
        if (start) begin
          next_state = COMPARE;
        end else begin
          next_state = DONE;
        end
      end
      
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic for each state
  always @(posedge clk) begin
    case (current_state)
      IDLE: begin
        done <= 1'b0;
        compute_done <= 1'b0;
        max_chain_cover <= 4'b0;
      end
      
      COMPARE: begin
        // Store inputs
        a_reg <= a_array;
        b_reg <= b_array;
        K_reg <= K;
        
        // Perform pairwise comparisons
        if (compare_counter < 8) begin
          for (int j = 0; j < 8; j++) begin
            if (j != compare_counter) begin
              dominance_matrix[compare_counter][j] = 
                ((a_reg[compare_counter] + K_reg) < a_reg[j]) || 
                ((b_reg[compare_counter] + K_reg) < b_reg[j]);
            end else begin
              dominance_matrix[compare_counter][j] = 1'b0;
            end
          end
          compare_counter <= compare_counter + 1;
        end
      end
      
      BUILD_GRAPH: begin
        // Initialize matching variables
        for (int i = 0; i < 8; i++) begin
          matchL[i] = 8'hFF;
          matchR[i] = 8'hFF;
        end
        match_iteration <= 3'b0;
      end
      
      COMPUTE_RANKS: begin
        // Implement maximum bipartite matching for minimum chain cover
        if (match_iteration < 8) begin
          // Reset visited and path for each augmentation
          for (int i = 0; i < 8; i++) begin
            visited[i] = 1'b0;
            path[i] = 8'hFF;
          end
          path_length <= 3'b0;
          
          // Try to find augmenting path starting from unmatched left nodes
          if (matchL[match_iteration] == 8'hFF) begin
            if (find_augmenting_path(match_iteration)) begin
              augment_path();
            end
          end
          match_iteration <= match_iteration + 1;
        end else begin
          // Calculate minimum chain cover size
          max_chain_cover = 8 - count_matches();
          compute_done <= 1'b1;
        end
      end
      
      DONE: begin
        max_ranks <= max_chain_cover;
        done <= 1'b1;
        compare_counter <= 3'b0;
      end
    endcase
  end

  // Function to find augmenting path using DFS
  function bit find_augmenting_path(input [2:0] start_node);
    begin
      visited[start_node] = 1'b1;
      path[path_length] = start_node;
      path_length <= path_length + 1;
      
      // Try all right nodes connected to this left node
      for (int j = 0; j < 8; j++) begin
        if (dominance_matrix[start_node][j] && matchR[j] == 8'hFF) begin
          // Found free right node - augmenting path found
          return 1'b1;
        end else if (dominance_matrix[start_node][j] && 
                    !visited[matchR[j]]) begin
          if (find_augmenting_path(matchR[j])) begin
            return 1'b1;
          end
        end
      end
      return 1'b0;
    end
  endfunction

  // Function to augment the path
  function void augment_path();
    begin
      // Flip matches along the path
      for (int i = 0; i < path_length - 1; i++) begin
        matchL[path[i]] = path[i + 1];
        matchR[path[i + 1]] = path[i];
      end
    end
  endfunction

  // Function to count total matches
  function [3:0] count_matches();
    begin
      count_matches = 4'b0;
      for (int i = 0; i < 8; i++) begin
        if (matchL[i] != 8'hFF) begin
          count_matches = count_matches + 1;
        end
      end
    end
  endfunction

endmodule