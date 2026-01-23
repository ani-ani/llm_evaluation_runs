module network_unused_switches (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_nodes,
  input [6:0] length_matrix [8:0][8:0],
  input [2:0] hop_matrix [8:0][8:0],
  output reg valid,
  output reg [7:0] unused_mask
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    COMPUTE_FORWARD,
    COMPUTE_BACKWARD,
    FIND_PARETO,
    CHECK_NODES,
    DONE
  } state_t;

  state_t state;
  reg [9:0] counter;

  // Forward and backward path data
  reg [6:0] forward_length [8:0];
  reg [2:0] forward_hops [8:0];
  reg [6:0] backward_length [8:0];
  reg [2:0] backward_hops [8:0];

  // Pareto frontier storage
  reg [6:0] pareto_length [0:7];
  reg [2:0] pareto_hops [0:7];
  reg [2:0] pareto_count;

  // Temporary variables for computation
  reg [6:0] temp_length [8:0];
  reg [2:0] temp_hops [8:0];
  reg [2:0] current_node;
  reg [2:0] target_node;
  reg [2:0] i, j, k;
  reg [6:0] min_length;
  reg [2:0] min_hops;
  reg found;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      counter <= 0;
      valid <= 0;
      unused_mask <= 8'b11111111;

      // Initialize all path data
      for (i = 0; i <= 8; i = i + 1) begin
        forward_length[i] <= 7'b1111111;
        forward_hops[i] <= 3'b111;
        backward_length[i] <= 7'b1111111;
        backward_hops[i] <= 3'b111;
      end

      // Initialize Pareto frontier
      pareto_count <= 0;
      for (i = 0; i < 8; i = i + 1) begin
        pareto_length[i] <= 0;
        pareto_hops[i] <= 0;
      end
    end
    else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COMPUTE_FORWARD;
            counter <= 0;
            valid <= 0;
            unused_mask <= 8'b11111111;

            // Initialize forward path from node 1
            forward_length[1] <= 0;
            forward_hops[1] <= 0;

            // Initialize backward path to node n
            backward_length[num_nodes] <= 0;
            backward_hops[num_nodes] <= 0;
          end
        end

        COMPUTE_FORWARD: begin
          // Dijkstra-like algorithm for forward paths
          if (counter < 8) begin
            // Find node with minimum length not yet processed
            min_length <= 7'b1111111;
            current_node <= 0;
            for (i = 1; i <= num_nodes; i = i + 1) begin
              if (forward_length[i] < min_length && forward_length[i] != 7'b1111111) begin
                min_length <= forward_length[i];
                current_node <= i;
              end
            end

            if (current_node != 0) begin
              // Update neighbors
              for (j = 1; j <= num_nodes; j = j + 1) begin
                if (length_matrix[current_node][j] != 0) begin
                  if (forward_length[j] > forward_length[current_node] + length_matrix[current_node][j]) begin
                    forward_length[j] <= forward_length[current_node] + length_matrix[current_node][j];
                    forward_hops[j] <= forward_hops[current_node] + hop_matrix[current_node][j];
                  end
                  else if (forward_length[j] == forward_length[current_node] + length_matrix[current_node][j] &&
                          forward_hops[j] > forward_hops[current_node] + hop_matrix[current_node][j]) begin
                    forward_hops[j] <= forward_hops[current_node] + hop_matrix[current_node][j];
                  end
                end
              end
              forward_length[current_node] <= 7'b1111111; // Mark as processed
            end
            counter <= counter + 1;
          end
          else begin
            state <= COMPUTE_BACKWARD;
            counter <= 0;
          end
        end

        COMPUTE_BACKWARD: begin
          // Dijkstra-like algorithm for backward paths
          if (counter < 8) begin
            // Find node with minimum length not yet processed
            min_length <= 7'b1111111;
            current_node <= 0;
            for (i = 1; i <= num_nodes; i = i + 1) begin
              if (backward_length[i] < min_length && backward_length[i] != 7'b1111111) begin
                min_length <= backward_length[i];
                current_node <= i;
              end
            end

            if (current_node != 0) begin
              // Update neighbors
              for (j = 1; j <= num_nodes; j = j + 1) begin
                if (length_matrix[j][current_node] != 0) begin
                  if (backward_length[j] > backward_length[current_node] + length_matrix[j][current_node]) begin
                    backward_length[j] <= backward_length[current_node] + length_matrix[j][current_node];
                    backward_hops[j] <= backward_hops[current_node] + hop_matrix[j][current_node];
                  end
                  else if (backward_length[j] == backward_length[current_node] + length_matrix[j][current_node] &&
                          backward_hops[j] > backward_hops[current_node] + hop_matrix[j][current_node]) begin
                    backward_hops[j] <= backward_hops[current_node] + hop_matrix[j][current_node];
                  end
                end
              end
              backward_length[current_node] <= 7'b1111111; // Mark as processed
            end
            counter <= counter + 1;
          end
          else begin
            state <= FIND_PARETO;
            counter <= 0;
            pareto_count <= 0;
          end
        end

        FIND_PARETO: begin
          // Find all Pareto-optimal paths from 1 to n
          if (counter < 8) begin
            found <= 0;
            // Check if current path is dominated
            for (i = 0; i < pareto_count; i = i + 1) begin
              if (pareto_length[i] <= forward_length[num_nodes] && pareto_hops[i] <= forward_hops[num_nodes]) begin
                found <= 1;
              end
              if (pareto_length[i] >= forward_length[num_nodes] && pareto_hops[i] >= forward_hops[num_nodes]) begin
                // Remove dominated entry
                for (j = i; j < pareto_count - 1; j = j + 1) begin
                  pareto_length[j] <= pareto_length[j + 1];
                  pareto_hops[j] <= pareto_hops[j + 1];
                end
                pareto_count <= pareto_count - 1;
              end
            end

            if (!found && forward_length[num_nodes] != 7'b1111111) begin
              pareto_length[pareto_count] <= forward_length[num_nodes];
              pareto_hops[pareto_count] <= forward_hops[num_nodes];
              pareto_count <= pareto_count + 1;
            end

            // Move to next potential path (simplified - in real implementation would need to explore all paths)
            counter <= counter + 1;
          end
          else begin
            state <= CHECK_NODES;
            counter <= 0;
            current_node <= 1;
          end
        end

        CHECK_NODES: begin
          if (counter < 2000) begin
            if (counter[9:0] == 0) begin
              // Check if current_node is on any Pareto-optimal path
              reg node_used;
              node_used <= 0;

              // Check all possible paths through current_node
              for (i = 0; i < pareto_count; i = i + 1) begin
                // Check if there exists a path 1->current_node->n that matches this Pareto point
                if (forward_length[current_node] + backward_length[current_node] == pareto_length[i] &&
                    forward_hops[current_node] + backward_hops[current_node] == pareto_hops[i]) begin
                  node_used <= 1;
                end
              end

              // Update unused_mask
              if (!node_used && current_node <= 8) begin
                unused_mask[current_node - 1] <= 1;
              end
              else if (current_node <= 8) begin
                unused_mask[current_node - 1] <= 0;
              end

              // Move to next node
              current_node <= current_node + 1;
              if (current_node > num_nodes) begin
                current_node <= 1;
              end
            end
            counter <= counter + 1;
          end
          else begin
            state <= DONE;
            valid <= 1;
          end
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            valid <= 0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule