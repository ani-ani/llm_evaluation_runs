module graph_partition (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [3:0] m,
  input [5:0] edges [15:0],
  output reg valid,
  output reg [3:0] arya_set,
  output reg [3:0] sansa_set,
  output reg done
);

  // State definitions
  typedef enum logic [4:0] {
    IDLE,
    SETUP_ADJ,
    GENERATE_PERMUTATION,
    CHECK_CLIQUE,
    UPDATE_RESULT,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Adjacency matrix (4x4)
  reg [3:0] adj_matrix [3:0];

  // Current permutation being checked
  reg [1:0] assignment [3:0]; // 0:Arya, 1:Sansa, 2:Jon, 3:unused

  // Counters for state machine
  reg [15:0] edge_counter;
  reg [15:0] perm_counter;
  reg [1:0] node_counter;
  reg [1:0] check_counter;

  // Temporary storage for clique checking
  reg [3:0] temp_arya, temp_sansa, temp_jon;
  reg clique_valid;

  // Result storage
  reg found_valid;

  // Initialize outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid <= 0;
      arya_set <= 0;
      sansa_set <= 0;
      done <= 0;
      current_state <= IDLE;
      found_valid <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all counters and registers
      edge_counter <= 0;
      perm_counter <= 0;
      node_counter <= 0;
      check_counter <= 0;
      clique_valid <= 0;
      temp_arya <= 0;
      temp_sansa <= 0;
      temp_jon <= 0;
      
      // Initialize adjacency matrix
      for (int i = 0; i < 4; i++) begin
        adj_matrix[i] <= 0;
      end
      
      // Initialize assignment
      for (int i = 0; i < 4; i++) begin
        assignment[i] <= 3; // unused
      end
    end else begin
      case (current_state)
        IDLE: begin
          if (start) begin
            next_state = SETUP_ADJ;
            edge_counter <= 0;
            // Initialize adjacency matrix
            for (int i = 0; i < 4; i++) begin
              adj_matrix[i] <= 0;
            end
          end else begin
            next_state = IDLE;
          end
        end

        SETUP_ADJ: begin
          if (edge_counter < m) begin
            // Extract edge information
            reg [1:0] u = edges[edge_counter][1:0];
            reg [1:0] v = edges[edge_counter][3:2];
            
            // Set both directions in adjacency matrix
            adj_matrix[u] <= adj_matrix[u] | (1 << v);
            adj_matrix[v] <= adj_matrix[v] | (1 << u);
            
            edge_counter <= edge_counter + 1;
          end else begin
            // Initialize permutation counter
            perm_counter <= 0;
            next_state = GENERATE_PERMUTATION;
          end
        end

        GENERATE_PERMUTATION: begin
          // Generate next permutation
          // City 1 must be in Arya (0), City 2 must be in Sansa (1)
          reg [1:0] city1 = 1;
          reg [1:0] city2 = 2;
          
          // Initialize assignment
          assignment[city1] <= 0; // Arya
          assignment[city2] <= 1; // Sansa
          
          // For other cities (0, 3), try all combinations
          reg [1:0] city0 = 0;
          reg [1:0] city3 = 3;
          
          // perm_counter encodes assignments for cities 0 and 3
          // Each has 3 possibilities (0,1,2)
          assignment[city0] <= perm_counter % 3;
          assignment[city3] <= (perm_counter / 3) % 3;
          
          // Move to clique checking
          node_counter <= 0;
          check_counter <= 0;
          clique_valid <= 1;
          next_state = CHECK_CLIQUE;
        end

        CHECK_CLIQUE: begin
          // Check if current assignment forms valid cliques
          // First, build the sets
          temp_arya <= 0;
          temp_sansa <= 0;
          temp_jon <= 0;
          
          for (int i = 0; i < n; i++) begin
            case (assignment[i])
              0: temp_arya <= temp_arya | (1 << i);
              1: temp_sansa <= temp_sansa | (1 << i);
              2: temp_jon <= temp_jon | (1 << i);
            endcase
          end
          
          // Check if all sets are cliques
          // Arya set check
          for (int i = 0; i < 4; i++) begin
            if (temp_arya[i]) begin
              for (int j = i+1; j < 4; j++) begin
                if (temp_arya[j]) begin
                  if (!(adj_matrix[i][j])) begin
                    clique_valid <= 0;
                  end
                end
              end
            end
          end
          
          // Sansa set check
          for (int i = 0; i < 4; i++) begin
            if (temp_sansa[i]) begin
              for (int j = i+1; j < 4; j++) begin
                if (temp_sansa[j]) begin
                  if (!(adj_matrix[i][j])) begin
                    clique_valid <= 0;
                  end
                end
              end
            end
          end
          
          // Jon set check
          for (int i = 0; i < 4; i++) begin
            if (temp_jon[i]) begin
              for (int j = i+1; j < 4; j++) begin
                if (temp_jon[j]) begin
                  if (!(adj_matrix[i][j])) begin
                    clique_valid <= 0;
                  end
                end
              end
            end
          end
          
          next_state = UPDATE_RESULT;
        end

        UPDATE_RESULT: begin
          if (clique_valid && !found_valid) begin
            // Found a valid partition
            found_valid <= 1;
            arya_set <= temp_arya;
            sansa_set <= temp_sansa;
          end
          
          // Move to next permutation
          perm_counter <= perm_counter + 1;
          
          // Check if we've tried all permutations
          if (perm_counter < 9) begin // 3^2 = 9 permutations for 2 cities
            next_state = GENERATE_PERMUTATION;
          end else begin
            next_state = DONE;
          end
        end

        DONE: begin
          valid <= found_valid;
          done <= 1;
          next_state = IDLE;
        end

        default: next_state = IDLE;
      endcase
    end
  end

endmodule