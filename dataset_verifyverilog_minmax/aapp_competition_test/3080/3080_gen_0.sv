module snack_distribution(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start processing query
  input [7:0][7:0] adjacency, // 8x8 adjacency matrix (1-bit edges)
  input [2:0] k, // Number of snack stands to select (1-4)
  input [2:0] a, // Number of target areas (1-8)
  input [2:0][2:0] targets, // Up to 8 target areas (3-bit IDs each)
  output reg [6:0] count, // Valid configuration count (up to 70)
  output reg done // High when computation complete
);

  // State definitions
  localparam IDLE = 0;
  localparam INIT = 1;
  localparam PATH_COMPUTE = 2;
  localparam SUBSET_GEN = 3;
  localparam VALIDATE = 4;
  localparam UPDATE_COUNT = 5;
  localparam DONE = 6;

  reg [2:0] state, next_state;
  reg [5:0] cycle_counter; // For general cycle counting
  
  // Path computation storage
  reg [7:0] path_masks [0:7][0:7][0:127]; // node, target, path index
  reg [6:0] path_counts [0:7][0:7]; // node, target
  reg [7:0] all_path_nodes; // Union of all path nodes
  
  // Subset generation
  reg [5:0] subset_index; // Current subset being processed
  reg [7:0] current_subset; // Current subset mask
  reg [6:0] total_subsets; // Total number of subsets for given k
  
  // Validation storage
  reg [6:0] path_idx; // Current path being validated
  reg [2:0] target_idx; // Current target being validated
  reg subset_valid; // Current subset validity flag
  reg [6:0] snack_count; // Number of snacks in current path
  
  // State machine logic
  always @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      count <= 0;
      done <= 0;
      cycle_counter <= 0;
      subset_index <= 0;
      total_subsets <= 0;
      current_subset <= 0;
      all_path_nodes <= 0;
    end else begin
      state <= next_state;
      
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            next_state <= INIT;
          end
        end
        
        INIT: begin
          cycle_counter <= cycle_counter + 1;
          
          // Initialize path storage
          if (cycle_counter < 64) begin
            path_counts[cycle_counter/8][cycle_counter%8] <= 0;
            all_path_nodes <= 0;
            if (cycle_counter == 0) begin
              count <= 0;
            end
          end else if (cycle_counter < 128) begin
            // Compute binomial coefficient for total subsets
            case (k)
              1: total_subsets <= 8;
              2: total_subsets <= 28;
              3: total_subsets <= 56;
              4: total_subsets <= 70;
              default: total_subsets <= 0;
            endcase
          end else if (cycle_counter < 192) begin
            // Precompute paths from root to each node (dynamic programming)
            reg [2:0] node_idx, target_idx;
            reg [6:0] path_idx, pred_idx;
            
            node_idx = (cycle_counter - 128) / 24;
            target_idx = ((cycle_counter - 128) % 24) / 3;
            
            if (node_idx < 8 && target_idx < a) begin
              if (node_idx == 0) begin
                // Root node
                if (targets[target_idx] == 0) begin
                  path_masks[0][target_idx][0] <= 8'b00000001;
                  path_counts[0][target_idx] <= 1;
                end else begin
                  path_counts[0][target_idx] <= 0;
                end
              end else begin
                // Non-root node
                path_counts[node_idx][target_idx] <= 0;
                for (pred_idx = 0; pred_idx < 8; pred_idx = pred_idx + 1) begin
                  if (adjacency[pred_idx][node_idx]) begin
                    for (path_idx = 0; path_idx < path_counts[pred_idx][target_idx]; path_idx = path_idx + 1) begin
                      path_masks[node_idx][target_idx][path_counts[node_idx][target_idx]] <= 
                        path_masks[pred_idx][target_idx][path_idx] | (1 << node_idx);
                      path_counts[node_idx][target_idx] <= path_counts[node_idx][target_idx] + 1;
                    end
                  end
                end
              end
            end
          end else if (cycle_counter < 256) begin
            // Compute all_path_nodes
            reg [2:0] node_idx, target_idx;
            for (node_idx = 0; node_idx < 8; node_idx = node_idx + 1) begin
              for (target_idx = 0; target_idx < a; target_idx = target_idx + 1) begin
                if (path_counts[node_idx][target_idx] > 0) begin
                  all_path_nodes <= all_path_nodes | (1 << node_idx);
                end
              end
            end
          end else begin
            next_state <= PATH_COMPUTE;
            cycle_counter <= 0;
          end
        end
        
        PATH_COMPUTE: begin
          cycle_counter <= cycle_counter + 1;
          
          if (cycle_counter < 8) begin
            // Ensure all paths are properly computed
            reg [2:0] node_idx, target_idx;
            node_idx = cycle_counter / 8;
            target_idx = cycle_counter % 8;
            
            if (node_idx < 8 && target_idx < a) begin
              if (node_idx > 0 && path_counts[node_idx][target_idx] == 0) begin
                // If no paths found, ensure empty set
                path_counts[node_idx][target_idx] <= 0;
              end
            end
          end else begin
            next_state <= SUBSET_GEN;
            cycle_counter <= 0;
            subset_index <= 0;
          end
        end
        
        SUBSET_GEN: begin
          if (subset_index < total_subsets) begin
            // Generate k-combination from index
            current_subset <= get_subset_from_index(subset_index, k);
            next_state <= VALIDATE;
            target_idx <= 0;
            path_idx <= 0;
            subset_valid <= 1;
          end else begin
            next_state <= DONE;
          end
        end
        
        VALIDATE: begin
          if (target_idx < a) begin
            if (path_idx < path_counts[targets[target_idx]][target_idx]) begin
              // Check if this path has exactly one snack from current_subset
              snack_count <= popcount(current_subset & path_masks[targets[target_idx]][target_idx][path_idx]);
              
              if (snack_count != 1) begin
                subset_valid <= 0;
              end
              
              path_idx <= path_idx + 1;
            end else begin
              target_idx <= target_idx + 1;
              path_idx <= 0;
            end
          end else if (subset_valid) begin
            // Check that all snacks in subset are on some path
            reg [6:0] i;
            subset_valid <= 0;
            for (i = 0; i < 8; i = i + 1) begin
              if (current_subset[i]) begin
                if (path_counts[i][target_idx-1] > 0) begin
                  subset_valid <= 1;
                end
              end
            end
          end else begin
            next_state <= UPDATE_COUNT;
          end
        end
        
        UPDATE_COUNT: begin
          if (subset_valid) begin
            count <= count + 1;
          end
          
          subset_index <= subset_index + 1;
          next_state <= SUBSET_GEN;
        end
        
        DONE: begin
          done <= 1;
        end
      endcase
    end
  end
  
  // Function to get subset from index using combinatorial number system
  function [7:0] get_subset_from_index;
    input [5:0] index;
    input [2:0] k;
    reg [7:0] result;
    reg [5:0] remaining;
    reg [2:0] i, j;
    begin
      result = 0;
      remaining = index;
      j = 0;
      
      for (i = 0; i < 8; i = i + 1) begin
        if ( ( (1 << (8-i-1)) - 1 ) >= ( ( ( (1 << k) - 1 ) - j ) >> (8-i-1) ) ) begin
          result = result | (1 << i);
          j = j + 1;
          if (j == k) break;
        end
      end
      
      get_subset_from_index = result;
    end
  endfunction
  
  // Function to count bits
  function [6:0] popcount;
    input [7:0] data;
    reg [6:0] count;
    integer i;
    begin
      count = 0;
      for (i = 0; i < 8; i = i + 1) begin
        if (data[i]) count = count + 1;
      end
      popcount = count;
    end
  endfunction
endmodule