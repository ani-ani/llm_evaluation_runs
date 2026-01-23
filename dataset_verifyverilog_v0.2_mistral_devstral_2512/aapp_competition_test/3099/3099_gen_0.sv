module spy_network (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_spies,
  input [7:0] enemy_mask,
  input [7:0] adj_matrix [0:7],
  output reg [3:0] min_messages,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    INIT,
    REACHABILITY,
    GREEDY,
    DONE
  } state_t;

  state_t state;
  reg [7:0] safe_nodes;
  reg [7:0] reach [0:7];
  reg [7:0] covered;
  reg [2:0] i, j, k;
  reg [2:0] selected_count;
  reg [2:0] max_coverage;
  reg [2:0] best_node;
  reg [2:0] temp_coverage;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      min_messages <= 0;
      done <= 0;
      i <= 0;
      j <= 0;
      k <= 0;
      selected_count <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
            done <= 0;
          end
        end

        INIT: begin
          // Initialize safe nodes
          safe_nodes <= ~enemy_mask & ((1 << num_spies) - 1);
          
          // Initialize reachability matrix
          for (i = 0; i < 8; i = i + 1) begin
            reach[i] <= adj_matrix[i] & safe_nodes;
          end
          
          // Initialize covered nodes
          covered <= 0;
          selected_count <= 0;
          i <= 0;
          j <= 0;
          k <= 0;
          
          state <= REACHABILITY;
        end

        REACHABILITY: begin
          // Floyd-Warshall algorithm
          if (k < num_spies) begin
            if (i < num_spies) begin
              if (j < num_spies) begin
                if (safe_nodes[k] && safe_nodes[i] && safe_nodes[j]) begin
                  reach[i][j] <= reach[i][j] | (reach[i][k] & reach[k][j]);
                end
                j <= j + 1;
              end else begin
                j <= 0;
                i <= i + 1;
              end
            end else begin
              i <= 0;
              k <= k + 1;
            end
          end else begin
            state <= GREEDY;
            i <= 0;
            j <= 0;
            max_coverage <= 0;
            best_node <= 0;
          end
        end

        GREEDY: begin
          if (selected_count < num_spies) begin
            // Find node with maximum coverage
            if (i < num_spies) begin
              if (safe_nodes[i] && !covered[i]) begin
                // Calculate coverage for node i
                temp_coverage <= 0;
                for (j = 0; j < num_spies; j = j + 1) begin
                  if (safe_nodes[j] && !covered[j] && reach[i][j]) begin
                    temp_coverage <= temp_coverage + 1;
                  end
                end
                
                // Update best node
                if (temp_coverage > max_coverage) begin
                  max_coverage <= temp_coverage;
                  best_node <= i;
                end
              end
              i <= i + 1;
            end else begin
              // Select best node
              if (max_coverage > 0) begin
                covered <= covered | (reach[best_node] & safe_nodes);
                selected_count <= selected_count + 1;
              end
              
              // Reset for next iteration
              i <= 0;
              max_coverage <= 0;
              best_node <= 0;
            end
          end else begin
            min_messages <= selected_count;
            done <= 1;
            state <= DONE;
          end
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule