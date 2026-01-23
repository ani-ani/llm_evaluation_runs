module cycle_decomposition (
  input clk,
  input rst_n,
  input start,
  input [5:0] node_count,
  input [5:0] edge_count,
  input [4:0] edge_from [63:0],
  input [4:0] edge_to [63:0],
  output reg valid,
  output reg [4:0] cycle_count,
  output reg [4:0] cycle_length [15:0],
  output reg [4:0] cycle_nodes [15:0][15:0],
  output reg [5:0] nodes_used
);

  // State machine states
  typedef enum logic [2:0] {
    IDLE,
    BUILD,
    CHECK,
    FIND_CYCLES,
    VALIDATE,
    DONE
  } state_t;
  state_t state, next_state;

  // Adjacency matrix (16x16 bits)
  reg [15:0] adj_matrix [15:0];

  // Visited nodes mask
  reg [15:0] visited;

  // Current cycle tracking
  reg [4:0] current_cycle_length;
  reg [4:0] current_cycle_nodes [15:0];
  reg [4:0] current_node;
  reg [4:0] start_node;
  reg [4:0] cycle_idx;
  reg [4:0] node_idx;
  reg [4:0] depth;

  // Edge selection
  reg [4:0] selected_edge;
  reg edge_found;

  // Counters
  reg [4:0] build_idx;
  reg [4:0] check_idx;
  reg [4:0] find_idx;
  reg [4:0] validate_idx;

  // Initialize outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid <= 0;
      cycle_count <= 0;
      for (int i = 0; i < 16; i++) begin
        cycle_length[i] <= 0;
        for (int j = 0; j < 16; j++) begin
          cycle_nodes[i][j] <= 0;
        end
      end
      nodes_used <= 0;
    end
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      next_state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // State transitions
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = BUILD;
      end
      BUILD: begin
        if (build_idx == edge_count) next_state = CHECK;
      end
      CHECK: begin
        if (check_idx == node_count) next_state = FIND_CYCLES;
      end
      FIND_CYCLES: begin
        if (find_idx == node_count) next_state = VALIDATE;
      end
      VALIDATE: begin
        if (validate_idx == node_count) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // State actions
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all internal registers
      for (int i = 0; i < 16; i++) adj_matrix[i] <= 0;
      visited <= 0;
      current_cycle_length <= 0;
      for (int i = 0; i < 16; i++) current_cycle_nodes[i] <= 0;
      current_node <= 0;
      start_node <= 0;
      cycle_idx <= 0;
      node_idx <= 0;
      depth <= 0;
      selected_edge <= 0;
      edge_found <= 0;
      build_idx <= 0;
      check_idx <= 0;
      find_idx <= 0;
      validate_idx <= 0;
    end else begin
      case (state)
        BUILD: begin
          if (build_idx < edge_count) begin
            adj_matrix[edge_from[build_idx]][edge_to[build_idx]] <= 1;
            build_idx <= build_idx + 1;
          end
        end
        CHECK: begin
          if (check_idx < node_count) begin
            // Check if node has at least one outgoing edge
            edge_found = 0;
            for (int i = 0; i < 16; i++) begin
              if (adj_matrix[check_idx][i]) begin
                edge_found = 1;
                break;
              end
            end
            if (!edge_found) begin
              // Invalid graph, reset to IDLE
              next_state = IDLE;
            end else begin
              check_idx <= check_idx + 1;
            end
          end
        end
        FIND_CYCLES: begin
          if (find_idx < node_count) begin
            if (!visited[find_idx]) begin
              // Start new cycle
              start_node = find_idx;
              current_node = find_idx;
              current_cycle_length = 0;
              depth = 0;
              // Find first outgoing edge
              selected_edge = 0;
              for (int i = 0; i < 16; i++) begin
                if (adj_matrix[current_node][i]) begin
                  selected_edge = i;
                  break;
                end
              end
              // Traverse cycle
              while (depth < 16) begin
                if (visited[selected_edge]) break;
                current_cycle_nodes[current_cycle_length] = current_node;
                current_cycle_length = current_cycle_length + 1;
                visited[current_node] = 1;
                current_node = selected_edge;
                if (current_node == start_node) begin
                  // Cycle complete
                  cycle_nodes[cycle_idx][current_cycle_length] = current_node;
                  cycle_length[cycle_idx] = current_cycle_length + 1;
                  cycle_idx = cycle_idx + 1;
                  break;
                end
                // Find next edge
                selected_edge = 0;
                for (int i = 0; i < 16; i++) begin
                  if (adj_matrix[current_node][i]) begin
                    selected_edge = i;
                    break;
                  end
                end
                depth = depth + 1;
              end
            end
            find_idx <= find_idx + 1;
          end
        end
        VALIDATE: begin
          if (validate_idx < node_count) begin
            if (!visited[validate_idx]) begin
              // Not all nodes visited, invalid
              next_state = IDLE;
            end else begin
              validate_idx <= validate_idx + 1;
            end
          end
        end
        DONE: begin
          valid <= 1;
          nodes_used <= visited;
          cycle_count <= cycle_idx;
        end
      endcase
    end
  end

endmodule